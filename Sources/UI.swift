// The menu bar popover: one row per screen, three switches, nothing else.
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
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      header
      VStack(spacing: 10) {
        ForEach(screens.all) { ScreenRow(screen: $0, screens: screens) }
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
    .foregroundStyle(Theme.text)
    .background(MenuSurface())
  }

  private var header: some View {
    HStack(spacing: 8) {
      Image(systemName: screens.all.contains(where: \.isOff) ? "curtains.closed" : "curtains.open")
        .font(Theme.Font.mark).foregroundStyle(Theme.accent)
      Text("Curtain").font(Theme.Font.wordmark)
      Spacer()
      Text(summary).font(Theme.Font.summary).foregroundStyle(Theme.textSecondary)
    }
  }

  private var summary: String {
    let off = screens.all.filter(\.isOff).count
    let total = screens.all.count
    return off == 0 ? "\(total) screen\(total == 1 ? "" : "s") on" : "\(off) of \(total) off"
  }

  private var footer: some View {
    HStack(spacing: 6) {
      HStack(spacing: 2) {
        ForEach(Array(Keys.shortcutLabel.enumerated()), id: \.offset) { Keycap(symbol: String($0.element)) }
      }
      Text("turns other screens off / on")
      Spacer()
      QuitButton()
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
  @StateObject private var hover = Hover()
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
        if screen.isOff {
          PillButton(title: "Turn on", systemImage: "power", prominent: true,
                     help: "Turn \(screen.name) back on") {
            if screen.curtained { screens.setCurtain(screen, closed: false) } else { screens.setQuickOff(screen, off: false) }
          }
        } else {
          let lastOn = !screens.canTurnOff(screen)
          PillButton(title: "Turn off", systemImage: "power", prominent: false,
                     help: lastOn ? "\(screen.name) is the only screen on, so it stays on. Turn another screen on first."
                                  : "Turn \(screen.name) black instantly. Windows stay on it." + (screen.isBuiltin ? "" : " Right-click to unplug it instead.")) {
            screens.setQuickOff(screen, off: true)
          }
          .disabled(lastOn)
          .contextMenu {
            if !screen.isBuiltin {
              Button("Unplug: move its windows to \(otherName) (every screen goes black for a few seconds)") {
                screens.setCurtain(screen, closed: true)
              }
            }
          }
        }
      }
      if screen.isOff {
        Text(screen.curtained ? "Unplugged. Its windows moved to \(otherName)." : "Off. Its windows are still there, hidden.")
          .font(Theme.Font.caption).foregroundStyle(Theme.textSecondary)
          .frame(maxWidth: .infinity, minHeight: Theme.Size.slider, alignment: .leading)
      } else {
        BrightnessSlider(value: Binding(get: { screen.brightness },
                                        set: { screens.setBrightness(screen, $0) }),
                         minimum: screen.minimum)
      }
    }
    .padding(12)
    .background(
      ZStack {
        shape.fill(hover.isHovered ? Theme.rowHover : Theme.row)
          .shadow(hover.isHovered ? Theme.rowShadowHover : Theme.rowShadow)
        DrawnCurtain(drawn: screen.isOff, reduceMotion: reduceMotion).clipShape(shape)
      }
    )
    .overlay(shape.strokeBorder(Theme.rowEdge, lineWidth: 1))
    .onHover { hover.isHovered = $0 }
    .animation(Theme.Motion.rowHover, value: hover.isHovered)
    .animation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.swap, value: screen.isOff)
  }

  private var otherName: String {
    screens.all.first { $0.id != screen.id && !$0.isOff }?.name ?? "your other screen"
  }
}

/// The curtain across a row that's off: pleated linen that spreads out from the left edge, its
/// folds opening as it goes, and gathers back when the screen comes on (a fade with Reduce
/// Motion). Drawn as one flattened layer so it moves smoothly.
struct DrawnCurtain: View {
  var drawn: Bool
  var reduceMotion: Bool

  var body: some View {
    GeometryReader { geo in
      Pleats()
        .drawingGroup()
        .scaleEffect(x: drawn || reduceMotion ? 1 : Theme.Size.gathered / max(1, geo.size.width), anchor: .leading)
        .shadow(Theme.curtainShadow)
        .opacity(drawn ? 1 : reduceMotion ? 0 : Theme.gatheredOpacity)
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .animation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.veil, value: drawn)
  }

  /// Folds side by side, each lit on its left and shaded on its right.
  private struct Pleats: View {
    var body: some View {
      GeometryReader { geo in
        HStack(spacing: 0) {
          ForEach(0..<Int((geo.size.width / Theme.Size.folds.min()!).rounded(.up)), id: \.self) { index in
            Rectangle()
              .fill(LinearGradient(colors: [Theme.pleatDark, Theme.pleatLight, Theme.pleatLight, Theme.pleatDark],
                                   startPoint: .leading, endPoint: .trailing))
              .frame(width: Theme.Size.folds[index % Theme.Size.folds.count])
          }
        }
        .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
        .clipped()
      }
    }
  }
}

/// A small labelled button: what it does is written on it.
struct PillButton: View {
  var title: String
  var systemImage: String
  var prominent: Bool
  var help: String
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .font(Theme.Font.button)
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .fixedSize()
    }
    .buttonStyle(PillStyle(prominent: prominent))
    .help(help)
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
    .accessibilityElement()
    .accessibilityLabel("Brightness")
    .accessibilityValue("\(Int((value * 100).rounded())) percent")
    .accessibilityAdjustableAction { direction in
      value = max(minimum, min(1, value + (direction == .increment ? 0.0625 : -0.0625)))
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
      .onHover { hover.isHovered = $0 }
      .animation(Theme.Motion.hover, value: hovered)
      .keyboardShortcut("q")
  }
}
