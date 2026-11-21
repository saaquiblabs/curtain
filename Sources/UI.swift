// The menu bar popover: one row per screen, three switches, nothing else.
// Its whole look comes from Theme (Linen & Dusk): colours, fonts, shapes, surface and timings.
// Layout (spacing, padding) still lives here; `make theme-check` guards the rest.

import SwiftUI

/// The menu. It takes its screens and keys from outside so it can be drawn from made-up
/// screens (Tools/render-menu); the app passes the shared ones.
struct PopoverView: View {
  @ObservedObject var screens: Screens
  @ObservedObject var keys: Keys

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
          LinkButton(title: "Allow Accessibility so the keys reach your monitor", systemImage: "hand.raised",
                     action: keys.askForPermission)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        SwitchRow(title: "Open at login", detail: nil, isOn: $screens.openAtLogin)
      }
      StitchedThread()
      footer
    }
    .padding(16)
    .frame(width: Theme.Size.panelWidth)
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
    HStack {
      Text("\(Keys.shortcutLabel)  turns other screens off / on")
      Spacer()
      QuitButton()
    }
    .font(Theme.Font.caption).foregroundStyle(Theme.textSecondary)
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
          .font(Theme.Font.icon).foregroundStyle(Theme.textSecondary).frame(width: 18)
        VStack(alignment: .leading, spacing: 1) {
          Text(screen.name).font(Theme.Font.title).lineLimit(1)
          if screen.control == .software && !screen.isOff {
            Text("dimmed in software").font(Theme.Font.caption).foregroundStyle(Theme.textFaint)
              .help("This monitor doesn't accept brightness commands, so Curtain darkens the picture instead.")
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
          PillButton(title: "Turn off", systemImage: "power", prominent: false,
                     help: "Turn \(screen.name) black instantly. Windows stay on it." + (screen.isBuiltin ? "" : " Right-click to unplug it instead.")) {
            screens.setQuickOff(screen, off: true)
          }
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
        Sheer(drawn: screen.isOff, reduceMotion: reduceMotion)
      }
      .clipShape(shape)
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

/// The sheer drawn across a row that's off: it slides in from the left (fades, with Reduce Motion).
struct Sheer: View {
  var drawn: Bool
  var reduceMotion: Bool

  var body: some View {
    GeometryReader { geo in
      ZStack {
        Rectangle().fill(LinearGradient(colors: Theme.veil, startPoint: .leading, endPoint: .trailing))
        Threads(step: Theme.Size.veilThreadStep, width: 1, axis: .vertical).fill(Theme.veilThread)
      }
      .offset(x: drawn || reduceMotion ? 0 : -geo.size.width * 1.01)
      .opacity(drawn || !reduceMotion ? 1 : 0)
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .animation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.veil, value: drawn)
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

    var body: some View {
      label
        .foregroundStyle(prominent ? Theme.solidPillText : Theme.pillText)
        .background(Capsule().fill(prominent ? (hover.isHovered ? Theme.solidPillHover : Theme.solidPill)
                                             : (hover.isHovered ? Theme.pillHover : Theme.pill)))
        .overlay { if !prominent { CapsuleOutline(color: Theme.pillEdge) } }
        .contentShape(Capsule())
        .onHover { hover.isHovered = $0 }
        .scaleEffect(pressed && !reduceMotion ? Theme.Motion.pressScale : 1)
        .opacity(pressed ? Theme.Motion.pressOpacity : 1)
        .animation(Theme.Motion.press, value: pressed)
        .animation(Theme.Motion.hover, value: hover.isHovered)
    }
  }
}

/// The brightness bar: a sheer fill with a faint weave that grows as you drag; a click far from
/// its edge glides there.
struct BrightnessSlider: View {
  @Binding var value: Double
  var minimum: Double
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { geo in
      let fraction = max(0, min(1, value))
      let height = geo.size.height
      ZStack(alignment: .leading) {
        Capsule().fill(Theme.track)
        ZStack {
          // The weave sits under the sheer's tint, so it only shows through faintly.
          Threads(step: Theme.Size.fillWeaveStep, width: 2, axis: .vertical).fill(Theme.fillWeave)
          Capsule().fill(LinearGradient(colors: Theme.fill, startPoint: .leading, endPoint: .trailing))
          // The soft right-hand edge of the sheer.
          CapsuleOutline(color: Theme.fillEdge)
            .mask(HStack(spacing: 0) { Spacer(minLength: 0); Rectangle().frame(width: height / 2) })
        }
        .clipShape(Capsule())
        .frame(width: max(height, geo.size.width * fraction))
        HStack {
          Image(systemName: "sun.min.fill").foregroundStyle(Theme.fillMark)
          Spacer()
          Text("\(Int((fraction * 100).rounded()))%")
            .font(Theme.Font.numeric)
            .foregroundStyle(fraction > Theme.Size.percentOnFillAbove ? Theme.percentOnFill : Theme.percent)
        }
        .font(Theme.Font.button)
        .padding(.horizontal, 8)
      }
      .contentShape(Capsule())
      .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
        let target = max(minimum, min(1, drag.location.x / geo.size.width))
        // Only the first touch glides (a click away from the edge); dragging follows the pointer.
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

  var body: some View {
    Button { isOn.toggle() } label: {
      ZStack(alignment: isOn ? .trailing : .leading) {
        Capsule().fill(isOn ? Theme.switchOn : Theme.switchOff)
        CapsuleOutline(color: Theme.switchEdge)
        Circle().fill(Theme.knob)
          .frame(width: Theme.Size.knob, height: Theme.Size.knob)
          .shadow(color: hover.isHovered ? Theme.knobShadowHover : Theme.knobShadow,
                  radius: hover.isHovered ? Theme.Size.knobShadowHover : Theme.Size.knobShadow, y: 1)
          .padding(2)
      }
      .frame(width: Theme.Size.switchWidth, height: Theme.Size.switchHeight)
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .onHover { hover.isHovered = $0 }
    .animation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.toggle, value: isOn)
    .animation(Theme.Motion.hover, value: hover.isHovered)
    .accessibilityRepresentation { Toggle(title, isOn: $isOn) }
  }
}

/// A plain text link with an icon (the Accessibility notice); underlined under the pointer.
struct LinkButton: View {
  var title: String
  var systemImage: String
  var action: () -> Void
  @StateObject private var hover = Hover()

  var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Image(systemName: systemImage)
        Text(title).underline(hover.isHovered)
      }
      .font(Theme.Font.caption).foregroundStyle(Theme.link)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { hover.isHovered = $0 }
  }
}

/// Quit, in the footer: brightens under the pointer.
struct QuitButton: View {
  @StateObject private var hover = Hover()

  var body: some View {
    Button("Quit") { NSApp.terminate(nil) } // applicationWillTerminate puts every screen back on
      .buttonStyle(.plain)
      .foregroundStyle(hover.isHovered ? Theme.text : Theme.textSecondary)
      .padding(.horizontal, 4).padding(.vertical, 2)
      .onHover { hover.isHovered = $0 }
      .animation(Theme.Motion.hover, value: hover.isHovered)
      .keyboardShortcut("q")
  }
}
