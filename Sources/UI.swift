// The menu bar popover: the desk map (Sources/DeskMap.swift), one row per screen, three switches.
// Its whole look comes from Theme (Linen & Dusk): colours, fonts, shapes, surface and timings.
// Layout (spacing, padding) still lives here; `make theme-check` guards the rest.

import SwiftUI

/// The menu. It takes its screens and keys from outside so it can be drawn from made-up
/// screens (Tools/render-menu); the app passes the shared ones.
struct PopoverView: View {
  @ObservedObject var screens: Screens
  @ObservedObject var keys: Keys
  /// Set by the app as the menu opens, so its content can come into focus.
  @ObservedObject var presence = MenuPresence()
  /// Which screen's tile or row is under the pointer (`make renders` sets one to show it lit).
  @ObservedObject var lit = LitScreen()
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    let mapShown = screens.all.count > 1
    VStack(alignment: .leading, spacing: 14) {
      header
      VStack(spacing: 6) {
        if mapShown { DeskMap(screens: screens, lit: lit) }
        HoverLine(lit: lit)
      }
      VStack(spacing: 10) {
        ForEach(screens.all) { ScreenRow(screen: $0, screens: screens, lit: lit, linked: mapShown) }
      }
      if let notice = screens.notice {
        HStack(alignment: .top, spacing: 6) {
          Image(systemName: "exclamationmark.circle")
          Text(notice).fixedSize(horizontal: false, vertical: true)
        }
        .font(Theme.Font.caption).foregroundStyle(Theme.textSecondary)
      }
      StitchedThread()
      VStack(spacing: 10) {
        SwitchRow(title: "Follow the Mac", detail: "Monitors match your MacBook's brightness", isOn: $screens.followMac)
        SwitchRow(title: "Brightness keys", detail: "Change the screen under the pointer", isOn: $keys.brightnessKeys)
        if keys.needsPermission {
          VStack(alignment: .leading, spacing: 3) {
            LinkButton(title: "Allow Accessibility so the keys reach your monitor", systemImage: "hand.raised",
                       action: keys.askForPermission)
            // A grant made for an older build still shows as on in System Settings (#11).
            Text("Already on? It's for an older Curtain: select Curtain there, remove it with −, then add it again.")
              .font(Theme.Font.caption).foregroundStyle(Theme.textSecondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        SwitchRow(title: "Open at login", detail: nil, isOn: $screens.openAtLogin)
      }
      StitchedThread()
      footer
    }
    .padding(16)
    .blur(radius: presence.shown || reduceMotion ? 0 : Theme.Motion.openBlur)
    .scaleEffect(presence.shown || reduceMotion ? 1 : Theme.Motion.openScale, anchor: .top)
    .frame(width: Theme.Size.panelWidth)
    // The menu's own size, so the panel can fit it as rows come and go (a monitor unplugged).
    .background(GeometryReader { proxy in
      Rectangle().hidden().preference(key: MenuSize.self, value: proxy.size)
    })
    .onPreferenceChange(MenuSize.self) { presence.resized?($0) }
    // A closing menu hears no pointer leaving, so a preview could still be up when it reopens.
    .onChange(of: presence.shown) { _ in lit.result = nil }
    .foregroundStyle(Theme.text)
    .background(MenuSurface())
  }

  private var header: some View {
    HStack(spacing: 8) {
      Image(systemName: screens.all.contains(where: \.isOff) ? "curtains.closed" : "curtains.open")
        .font(Theme.Font.mark).foregroundStyle(Theme.accent)
        .accessibilityHidden(true) // the summary beside it says the same in words
      Text("Curtain").font(Theme.Font.wordmark)
      Spacer()
      Text(summary).font(Theme.Font.summary).foregroundStyle(Theme.textSecondary)
    }
  }

  private var summary: String {
    Wording.summary(off: screens.all.filter(\.isOff).count, total: screens.all.count)
  }

  private var footer: some View {
    HStack(spacing: 6) {
      HStack(spacing: 6) {
        HStack(spacing: 2) {
          ForEach(Array(Keys.shortcutLabel.enumerated()), id: \.offset) { Keycap(symbol: String($0.element)) }
        }
        Text("turns other screens off / on")
      }
      // One line for VoiceOver, keys as words: "Control Option C turns other screens off / on".
      .accessibilityElement(children: .ignore)
      .accessibilityAddTraits(.isStaticText)
      .accessibilityLabel(Wording.spokenKeys(Keys.shortcutLabel) + " turns other screens off / on")
      Spacer()
      QuitButton(lit: lit)
    }
    .font(Theme.Font.caption).foregroundStyle(Theme.textSecondary)
  }
}

/// Whether the menu is showing; the app flips it as the panel opens and closes. `resized` hears
/// the menu's size whenever its content changes, so the panel can fit it (not published: setting
/// it redraws nothing).
final class MenuPresence: ObservableObject {
  @Published var shown = true
  var resized: ((CGSize) -> Void)?
}

private struct MenuSize: PreferenceKey {
  static var defaultValue = CGSize.zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

/// One key of a shortcut, drawn as a small raised keycap.
struct Keycap: View {
  var symbol: String

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: Theme.Radius.keycap, style: .continuous)
    Text(symbol)
      .font(Theme.Font.keycap)
      .frame(minWidth: Theme.Size.keycap, minHeight: Theme.Size.keycap)
      .background(shape.fill(Theme.pill).shadow(Theme.pillShadow))
      .overlay(shape.strokeBorder(Theme.rowEdge, lineWidth: 1))
  }
}

/// The panel's cloth over the frosted glass: a linen (or twilight) tint, a fine weave, a light edge.
struct MenuSurface: View {
  var body: some View {
    let shape = RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous)
    ZStack {
      shape.fill(Theme.panel)
      Threads(step: Theme.Size.weaveStep, width: 1, axis: .horizontal).fill(Theme.weaveAcross)
      Threads(step: Theme.Size.weaveStep, width: 1, axis: .vertical).fill(Theme.weaveDown)
    }
    .clipShape(shape)
    .overlay(shape.strokeBorder(Theme.panelEdge, lineWidth: 1))
  }
}

/// Evenly spaced threads, for weaves and sheers. Vertical threads run top to bottom.
struct Threads: Shape {
  var step: CGFloat
  var width: CGFloat
  var axis: Axis

  func path(in rect: CGRect) -> Path {
    var path = Path()
    var at: CGFloat = 0
    while at < (axis == .vertical ? rect.width : rect.height) {
      path.addRect(axis == .vertical ? CGRect(x: rect.minX + at, y: rect.minY, width: width, height: rect.height)
                                     : CGRect(x: rect.minX, y: rect.minY + at, width: rect.width, height: width))
      at += step
    }
    return path
  }
}

/// A capsule's 1 pt outline, drawn as a filled ring. (Stroking a fully rounded shape leaves
/// stray ticks at its ends when the menu is rendered offscreen; a fill doesn't.)
struct CapsuleOutline: View {
  var color: Color

  var body: some View {
    Ring().fill(color, style: FillStyle(eoFill: true))
  }

  private struct Ring: Shape {
    func path(in rect: CGRect) -> Path {
      var path = Capsule().path(in: rect)
      path.addPath(Capsule().path(in: rect.insetBy(dx: 1, dy: 1)))
      return path
    }
  }
}

/// The divider: a stitched, dashed thread.
struct StitchedThread: View {
  var body: some View {
    Stitch()
      .stroke(Theme.thread, style: StrokeStyle(lineWidth: 1, dash: Theme.Size.stitch))
      .opacity(Theme.threadOpacity)
      .frame(height: 1)
  }

  private struct Stitch: Shape {
    func path(in rect: CGRect) -> Path {
      Path { $0.move(to: CGPoint(x: rect.minX, y: rect.midY)); $0.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) }
    }
  }
}

/// Whether the pointer is over a view. (No `@State` with the command line tools: see STATUS.)
final class Hover: ObservableObject {
  @Published var isHovered = false
}

/// Draws every control as if the pointer were over it, so `make renders` can show hover states.
private struct HoverPreview: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
  var hoverPreview: Bool {
    get { self[HoverPreview.self] }
    set { self[HoverPreview.self] = newValue }
  }
}

extension View {
  /// The pointing hand over a control you can click, the arrow while it's disabled (#10). One
  /// modifier for every control in the menu.
  func clickable() -> some View { modifier(Clickable()) }
}

private struct Clickable: ViewModifier {
  @Environment(\.isEnabled) private var isEnabled

  func body(content: Content) -> some View {
    content.background(CursorArea(pointer: Pointer.over(clickable: true, enabled: isEnabled)))
  }
}

/// An AppKit view behind the control that shows the hand over it. Two ways, because the menu is a
/// non-activating panel and Curtain usually isn't the active app: a cursor rectangle (the window
/// puts the arrow back outside it), and an always-active tracking area that sets the hand on
/// entering and moving and the arrow on leaving. If the control goes away under the pointer (a
/// pill that swaps, a slider that goes when its screen turns off) the arrow comes back, so the
/// hand can't get stuck the way a pushed cursor can. It never takes clicks.
private struct CursorArea: NSViewRepresentable {
  var pointer: Pointer

  func makeNSView(context: Context) -> CursorView { CursorView() }
  func updateNSView(_ view: CursorView, context: Context) { view.pointer = pointer }

  final class CursorView: NSView {
    var pointer = Pointer.arrow {
      didSet {
        guard pointer != oldValue else { return }
        window?.invalidateCursorRects(for: self)
        if inside { show() }
      }
    }
    private var inside = false

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func resetCursorRects() {
      if pointer == .hand { addCursorRect(bounds, cursor: .pointingHand) }
    }

    override func updateTrackingAreas() {
      super.updateTrackingAreas()
      trackingAreas.forEach(removeTrackingArea)
      addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                                     owner: self))
    }

    override func mouseEntered(with event: NSEvent) { inside = true; show() }
    override func mouseMoved(with event: NSEvent) { if inside { show() } }
    override func mouseExited(with event: NSEvent) { inside = false; NSCursor.arrow.set() }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
      if newWindow == nil && inside { inside = false; NSCursor.arrow.set() }
      super.viewWillMove(toWindow: newWindow)
    }

    private func show() { (pointer == .hand ? NSCursor.pointingHand : NSCursor.arrow).set() }
  }
}

struct ScreenRow: View {
  @ObservedObject var screen: Screen
  @ObservedObject var screens: Screens
  /// The screen lit on the desk map; this row lights up with its tile.
  @ObservedObject var lit: LitScreen
  /// Whether there's a map to light up with (two screens or more).
  var linked: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: screen.isBuiltin ? "laptopcomputer" : "display")
          .font(Theme.Font.icon)
          .foregroundStyle(screen.isOff ? Theme.textSecondary : Theme.accent)
          .frame(width: Theme.Size.badge, height: Theme.Size.badge)
          .background(Circle().fill(screen.isOff ? Theme.badgeOff : Theme.badge))
          .accessibilityHidden(true) // the screen's name follows
        VStack(alignment: .leading, spacing: 1) {
          Text(screen.name).font(Theme.Font.title).lineLimit(1)
          if screen.control == .software && !screen.isOff {
            // Its line is kept at 100% too, just invisible, so the row doesn't jump while the
            // slider crosses 100%.
            let shown = QuitNote.shows(dimmedInSoftware: true, isOff: false, brightness: screen.brightness)
            Text("Dimmed by Curtain until it quits").font(Theme.Font.caption).foregroundStyle(Theme.textFaint)
              .lineLimit(1)
              .opacity(shown ? 1 : 0)
              .accessibilityHidden(!shown)
              .help("This monitor doesn't accept brightness commands, so Curtain darkens the picture instead. It goes back to full brightness when Curtain quits.")
          }
        }
        .layoutPriority(1)
        Spacer(minLength: 4)
        let lastOn = !screen.isOff && !screens.canTurnOff(screen)
        ForEach(RowButtons.buttons(isBuiltin: screen.isBuiltin, turnedOff: screen.blackedOut,
                                   disconnected: screen.curtained), id: \.self) { kind in
          let result = ScreenRow.result(kind, screen: screen, other: otherName, onlyOneOn: lastOn)
          switch kind {
          case .disconnect:
            PillButton(title: "Disconnect", systemImage: "cable.connector.slash", prominent: false, result: result, lit: lit) {
              screens.setCurtain(screen, closed: true)
            }
            .disabled(lastOn)
          case .turnOff:
            PillButton(title: "Turn off", systemImage: "power", prominent: false, result: result, lit: lit) {
              screens.turnOff([screen])
            }
            .disabled(lastOn)
          case .turnOn:
            PillButton(title: "Turn on", systemImage: "power", prominent: true, result: result, lit: lit) {
              screens.setQuickOff(screen, off: false)
            }
          case .reconnect:
            PillButton(title: "Reconnect", systemImage: "cable.connector", prominent: true, result: result, lit: lit) {
              screens.setCurtain(screen, closed: false)
            }
          }
        }
      }
      if screen.isOff {
        Text(Wording.offLine(disconnected: screen.curtained, other: otherName))
          .font(Theme.Font.caption).foregroundStyle(Theme.textSecondary)
          .frame(maxWidth: .infinity, minHeight: Theme.Size.slider, alignment: .leading)
      } else {
        BrightnessSlider(value: Binding(get: { screen.brightness },
                                        set: { screens.setBrightness(screen, $0) }),
                         minimum: screen.minimum, label: Wording.sliderLabel(screen: screen.name)) { pointed in
          // The tile's glow follows the pointer along the bar (#26).
          let result = ScreenRow.brightnessResult(screen: screen, to: pointed ?? screen.brightness)
          lit.hover(result, pointed != nil)
        }
      }
    }
    .padding(12)
    .background(
      ZStack {
        shape.fill(isLit ? Theme.rowHover : Theme.row)
          .shadow(isLit ? Theme.rowShadowHover : Theme.rowShadow)
        Drapes(closed: screen.isOff ? 1 : 0, real: screen.isOff, reduceMotion: reduceMotion).clipShape(shape)
      }
    )
    .overlay(shape.strokeBorder(isLit && linked ? Theme.rowEdgeLit : Theme.rowEdge, lineWidth: 1))
    .onHover { lit.hover(screen.id, $0) }
    .animation(Theme.Motion.rowHover, value: isLit)
    .animation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.swap, value: screen.isOff)
  }

  /// Under the pointer, or its tile is.
  private var isLit: Bool { lit.id == screen.id }

  private var otherName: String {
    screens.all.first { $0.id != screen.id && !$0.isOff }?.name ?? "your other screen"
  }

  /// What a row button would do: its line under the map, and its tile's preview unless it's
  /// disabled (the only screen on) (#26). `make renders` draws each one.
  static func result(_ kind: RowButtons.Kind, screen: Screen, other: String, onlyOneOn: Bool) -> HoverResult {
    let (preview, line): (TilePreview.Preview?, String)
    switch kind {
    case .disconnect:
      (preview, line) = (onlyOneOn ? nil : .disconnect,
                         Wording.disconnectLine(screen: screen.name, other: other, onlyOneOn: onlyOneOn))
    case .turnOff:
      (preview, line) = (onlyOneOn ? nil : .turnOff, Wording.turnOffLine(screen: screen.name, onlyOneOn: onlyOneOn))
    case .turnOn: (preview, line) = (.turnOn, Wording.turnOnLine(screen: screen.name))
    case .reconnect: (preview, line) = (.reconnect, Wording.reconnectLine(screen: screen.name))
    }
    return HoverResult(control: "\(screen.id) \(kind)", screen: screen.id, preview: preview, line: line)
  }

  static func brightnessResult(screen: Screen, to value: Double) -> HoverResult {
    HoverResult(control: "\(screen.id) slider", screen: screen.id, preview: .brightness(value),
                line: Wording.brightnessLine(screen: screen.name, to: value))
  }
}

/// The line under the desk map: what the control under the pointer would do (#26). Its room is
/// kept while nothing is under the pointer, so the menu doesn't jump. VoiceOver hears the same
/// line as each control's hint instead.
struct HoverLine: View {
  @ObservedObject var lit: LitScreen
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Text(lit.result?.line ?? " ")
      .font(Theme.Font.caption).foregroundStyle(Theme.textSecondary)
      .lineLimit(1).truncationMode(.middle)
      .frame(maxWidth: .infinity)
      .opacity(lit.result == nil ? 0 : 1)
      .animation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.preview, value: lit.result == nil)
      .accessibilityHidden(true)
  }
}

/// Quit's result: every tile that's off or disconnected comes halfway back (#26).
extension HoverResult {
  static let quit = HoverResult(control: "quit", screen: nil, preview: .quit, line: Wording.quitLine)
}

/// A small labelled button: what it does is written on it.
struct PillButton: View {
  var title: String
  var systemImage: String
  var prominent: Bool
  /// What it would do, shown on its tile and under the map while it's under the pointer (#26).
  var result: HoverResult
  @ObservedObject var lit: LitScreen
  var action: () -> Void

  var body: some View {
    // A click ends the preview: the real change takes over, and the button that takes this one's
    // place (Turn on for Turn off) waits for the pointer to come back before it previews.
    Button { lit.result = nil; action() } label: {
      Label(title, systemImage: systemImage)
        .font(Theme.Font.button)
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .fixedSize()
    }
    .buttonStyle(PillStyle(prominent: prominent))
    .onHover { lit.hover(result, $0) }
    .accessibilityHint(result.line)
  }
}

/// Ghost pill with a thin outline (Turn off), or a solid pill (Turn on).
struct PillStyle: ButtonStyle {
  var prominent: Bool

  func makeBody(configuration: Configuration) -> some View {
    PillBody(label: configuration.label, pressed: configuration.isPressed, prominent: prominent)
  }

  private struct PillBody<Content: View>: View {
    var label: Content
    var pressed: Bool
    var prominent: Bool
    @StateObject private var hover = Hover()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.hoverPreview) private var hoverPreview

    var body: some View {
      let hovered = (hover.isHovered || hoverPreview) && isEnabled
      label
        .opacity(isEnabled ? 1 : Theme.unavailable)
        .foregroundStyle(prominent ? Theme.solidPillText : (hovered ? Theme.pillTextHover : Theme.pillText))
        .background(Capsule().fill(prominent ? (hovered ? Theme.solidPillHover : Theme.solidPill)
                                             : (hovered ? Theme.pillHover : Theme.pill))
                      .shadow(prominent ? (hovered ? Theme.solidPillGlowHover : Theme.solidPillGlow) : Theme.pillShadow))
        .overlay { if !prominent { CapsuleOutline(color: hovered ? Theme.pillEdgeHover : Theme.pillEdge) } }
        .contentShape(Capsule())
        .clickable()
        .onHover { hover.isHovered = $0 }
        .scaleEffect(pressed && !reduceMotion ? Theme.Motion.pressScale : 1)
        .opacity(pressed ? Theme.Motion.pressOpacity : 1)
        .animation(Theme.Motion.press, value: pressed)
        .animation(Theme.Motion.hover, value: hovered)
    }
  }
}

/// The brightness bar: a sheer fill with a knob at its end that carries the sun and follows the
/// pointer (the sun grows brighter as you go up). A click far from the knob glides there.
struct BrightnessSlider: View {
  @Binding var value: Double
  var minimum: Double
  /// What VoiceOver calls it: names its screen.
  var label: String
  /// The brightness under the pointer as it moves along the bar, nil once it leaves (#26).
  var pointing: (Double?) -> Void = { _ in }
  @StateObject private var hover = Hover()
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.hoverPreview) private var hoverPreview

  var body: some View {
    let hovered = hover.isHovered || hoverPreview
    GeometryReader { geo in
      let fraction = max(0, min(1, value))
      let height = geo.size.height
      let travel = geo.size.width - height                 // how far the knob's centre can move
      let fillWidth = height + travel * fraction
      let knob = height - Theme.Size.sliderKnobInset * 2
      let percentInside = fillWidth > geo.size.width - Theme.Size.percentRoom
      ZStack(alignment: .leading) {
        Capsule().fill(hovered ? Theme.trackHover : Theme.track)
        Capsule().fill(LinearGradient(colors: Theme.trackShade, startPoint: .top, endPoint: .center))
        ZStack {
          // The weave sits under the sheer's tint, so it only shows through faintly.
          Threads(step: Theme.Size.fillWeaveStep, width: 2, axis: .vertical).fill(Theme.fillWeave)
          Capsule().fill(LinearGradient(colors: Theme.fill, startPoint: .leading, endPoint: .trailing))
          Capsule().fill(LinearGradient(colors: Theme.fillHighlight, startPoint: .top, endPoint: .center))
        }
        .clipShape(Capsule())
        .shadow(Theme.fillGlow)
        .frame(width: fillWidth)
        Text("\(Int((fraction * 100).rounded()))%")
          .font(Theme.Font.numeric)
          .foregroundStyle(percentInside ? Theme.percentOnFill : Theme.percent)
          .frame(width: percentInside ? fillWidth - height - Theme.Size.percentGap : geo.size.width - Theme.Size.percentGap,
                 alignment: .trailing)
        Circle().fill(Theme.knob)
          .frame(width: knob, height: knob)
          .shadow(hovered ? Theme.knobShadowHover : Theme.knobShadow)
          .overlay(
            Image(systemName: fraction < 0.5 ? "sun.min.fill" : "sun.max.fill")
              .font(Theme.Font.button)
              .foregroundStyle(Theme.knobMark)
              .scaleEffect(Theme.Size.sunScale.lowerBound + (Theme.Size.sunScale.upperBound - Theme.Size.sunScale.lowerBound) * fraction)
          )
          .scaleEffect(hovered && !reduceMotion ? Theme.Size.knobHoverScale : 1)
          .offset(x: fillWidth - height + Theme.Size.sliderKnobInset)
      }
      .contentShape(Capsule())
      .clickable()
      .onHover { hover.isHovered = $0 }
      .onContinuousHover { phase in
        switch phase {
        case .active(let at): pointing(max(minimum, min(1, (at.x - height / 2) / max(1, travel))))
        case .ended: pointing(nil)
        }
      }
      .animation(Theme.Motion.hover, value: hovered)
      .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
        let target = max(minimum, min(1, (drag.location.x - height / 2) / max(1, travel)))
        // Only the first touch glides (a click away from the knob); dragging follows the pointer.
        if drag.translation == .zero && abs(target - value) > Theme.Motion.sliderJump && !reduceMotion {
          withAnimation(Theme.Motion.slider) { value = target }
        } else {
          value = target
        }
      })
    }
    .frame(height: Theme.Size.slider)
    // VoiceOver sees an ordinary slider: its screen's name, the percent the bar shows, and
    // VO-arrows step it by 1/16 like the brightness keys.
    .accessibilityRepresentation {
      Slider(value: $value, in: minimum...1, step: 0.0625) { Text(label) }
        .accessibilityValue("\(Int((value * 100).rounded())) percent")
    }
  }
}

struct SwitchRow: View {
  var title: String
  var detail: String?
  @Binding var isOn: Bool

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 1) {
        Text(title).font(Theme.Font.body)
        if let detail { Text(detail).font(Theme.Font.caption).foregroundStyle(Theme.textSecondary) }
      }
      Spacer(minLength: 0)
      OutlinedSwitch(title: title, isOn: $isOn)
    }
  }
}

/// An outlined track with a white knob. VoiceOver sees an ordinary switch.
struct OutlinedSwitch: View {
  var title: String
  @Binding var isOn: Bool
  @StateObject private var hover = Hover()
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.hoverPreview) private var hoverPreview

  var body: some View {
    let hovered = hover.isHovered || hoverPreview
    Button { isOn.toggle() } label: {
      ZStack(alignment: isOn ? .trailing : .leading) {
        Capsule().fill(isOn ? (hovered ? Theme.switchOnHover : Theme.switchOn) : (hovered ? Theme.switchOffHover : Theme.switchOff))
          .shadow(isOn ? (hovered ? Theme.switchGlowHover : Theme.switchGlow) : .none)
        CapsuleOutline(color: Theme.switchEdge)
        Circle().fill(Theme.knob)
          .frame(width: Theme.Size.knob, height: Theme.Size.knob)
          .shadow(hovered ? Theme.knobShadowHover : Theme.knobShadow)
          .padding(Theme.Size.knobInset)
      }
      .frame(width: Theme.Size.switchWidth, height: Theme.Size.switchHeight)
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .clickable()
    .onHover { hover.isHovered = $0 }
    .animation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.toggle, value: isOn)
    .animation(Theme.Motion.hover, value: hovered)
    .accessibilityRepresentation { Toggle(title, isOn: $isOn) }
  }
}

/// A plain text link with an icon (the Accessibility notice); underlined under the pointer.
struct LinkButton: View {
  var title: String
  var systemImage: String
  var action: () -> Void
  @StateObject private var hover = Hover()
  @Environment(\.hoverPreview) private var hoverPreview

  var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Image(systemName: systemImage)
        Text(title).underline(hover.isHovered || hoverPreview)
      }
      .font(Theme.Font.caption).foregroundStyle(Theme.link)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .clickable()
    .onHover { hover.isHovered = $0 }
  }
}

/// Quit, in the footer: brightens on a faint pill under the pointer.
struct QuitButton: View {
  /// Quit's result shows on the map: every screen that's off comes halfway back (#26).
  @ObservedObject var lit: LitScreen
  @StateObject private var hover = Hover()
  @Environment(\.hoverPreview) private var hoverPreview

  var body: some View {
    let hovered = hover.isHovered || hoverPreview
    Button("Quit") { NSApp.terminate(nil) } // applicationWillTerminate puts every screen back on
      .buttonStyle(.plain)
      .foregroundStyle(hovered ? Theme.text : Theme.textSecondary)
      .padding(.horizontal, 6).padding(.vertical, 2)
      .background(Capsule().fill(hovered ? Theme.quitHover : .clear))
      .contentShape(Capsule())
      .clickable()
      .onHover { hover.isHovered = $0; lit.hover(.quit, $0) }
      .animation(Theme.Motion.hover, value: hovered)
      .accessibilityHint(Wording.quitLine)
      .keyboardShortcut("q")
  }
}
