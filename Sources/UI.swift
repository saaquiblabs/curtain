// The menu bar popover: one row per screen, three switches, nothing else.

import SwiftUI

extension Color {
  static let tangerine = Color(red: 1.0, green: 0.478, blue: 0.2)          // #FF7A33, Saaquib Labs
  static let navy = Color(red: 0.122, green: 0.173, blue: 0.369)            // #1F2C5E
}

struct PopoverView: View {
  @ObservedObject var screens = Screens.shared
  @ObservedObject var keys = Keys.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      header
      VStack(spacing: 10) {
        ForEach(screens.all) { ScreenRow(screen: $0) }
      }
      if let notice = screens.notice {
        Label(notice, systemImage: "exclamationmark.circle")
          .font(.caption).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Divider()
      VStack(spacing: 10) {
        SwitchRow(title: "Follow the Mac", detail: "Monitors match your MacBook's brightness", isOn: $screens.followMac)
        SwitchRow(title: "Brightness keys", detail: "Change the screen under the pointer", isOn: $keys.brightnessKeys)
        if keys.needsPermission {
          Button(action: keys.askForPermission) {
            Label("Allow Accessibility so the keys reach your monitor", systemImage: "hand.raised")
              .font(.caption)
          }
          .buttonStyle(.link).frame(maxWidth: .infinity, alignment: .leading)
        }
        SwitchRow(title: "Open at login", detail: nil, isOn: $screens.openAtLogin)
      }
      Divider()
      footer
    }
    .padding(16)
    .frame(width: 320)
  }

  private var header: some View {
    HStack(spacing: 8) {
      Image(systemName: screens.all.contains(where: \.curtained) ? "curtains.closed" : "curtains.open")
        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.tangerine)
      Text("Curtain").font(.system(size: 15, weight: .semibold))
      Spacer()
      Text(summary).font(.caption).foregroundStyle(.secondary)
    }
  }

  private var summary: String {
    let off = screens.all.filter(\.curtained).count
    let total = screens.all.count
    return off == 0 ? "\(total) screen\(total == 1 ? "" : "s") on" : "\(off) of \(total) off"
  }

  private var footer: some View {
    HStack {
      Text("\(Keys.shortcutLabel)  draws or opens the curtain")
        .font(.caption).foregroundStyle(.secondary)
      Spacer()
      Button("Quit") { AppDelegate.quit() }
        .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
        .keyboardShortcut("q")
    }
  }
}

struct ScreenRow: View {
  @ObservedObject var screen: Screen

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: screen.isBuiltin ? "laptopcomputer" : "display")
          .font(.system(size: 13)).foregroundStyle(.secondary).frame(width: 18)
        Text(screen.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
        if screen.control == .software && !screen.curtained {
          Text("dimmed in software").font(.caption2).foregroundStyle(.tertiary)
            .help("This monitor doesn't accept brightness commands, so Curtain darkens the picture instead.")
        }
        Spacer()
        CurtainButton(drawn: screen.curtained) {
          Screens.shared.setCurtain(screen, closed: !screen.curtained)
        }
      }
      if screen.curtained {
        Text("Curtain drawn. This screen is off.")
          .font(.caption).foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
      } else {
        BrightnessSlider(value: Binding(get: { screen.brightness },
                                        set: { Screens.shared.setBrightness(screen, $0) }),
                         minimum: screen.minimum)
      }
    }
    .padding(12)
    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.6)))
    .animation(.easeOut(duration: 0.18), value: screen.curtained)
  }
}

/// A Control Center–style brightness bar: a thick capsule that fills as you drag.
struct BrightnessSlider: View {
  @Binding var value: Double
  var minimum: Double

  var body: some View {
    GeometryReader { geo in
      let fraction = max(0, min(1, value))
      ZStack(alignment: .leading) {
        Capsule().fill(.quaternary)
        Capsule()
          .fill(LinearGradient(colors: [Color.tangerine.opacity(0.85), Color.tangerine], startPoint: .leading, endPoint: .trailing))
          .frame(width: max(26, geo.size.width * fraction))
        HStack {
          Image(systemName: "sun.min.fill").foregroundStyle(.white)
          Spacer()
          Text("\(Int((fraction * 100).rounded()))%")
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(fraction > 0.85 ? Color.white : Color.secondary)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 8)
      }
      .contentShape(Capsule())
      .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
        value = max(minimum, min(1, drag.location.x / geo.size.width))
      })
    }
    .frame(height: 26)
    .accessibilityElement()
    .accessibilityLabel("Brightness")
    .accessibilityValue("\(Int((value * 100).rounded())) percent")
    .accessibilityAdjustableAction { direction in
      value = max(minimum, min(1, value + (direction == .increment ? 0.0625 : -0.0625)))
    }
  }
}

struct CurtainButton: View {
  var drawn: Bool
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: drawn ? "curtains.closed" : "curtains.open")
        .font(.system(size: 12, weight: .semibold))
    }
    .buttonStyle(CircleButtonStyle(filled: drawn))
    .help(drawn ? "Open the curtain: switch this screen back on" : "Draw the curtain: switch this screen off")
    .accessibilityLabel(drawn ? "Switch screen on" : "Switch screen off")
  }
}

/// No @State here: the command line tools ship without SwiftUI's macro plugin.
struct CircleButtonStyle: ButtonStyle {
  var filled: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(filled ? Color.white : Color.primary)
      .frame(width: 28, height: 28)
      .background(Circle().fill(filled ? AnyShapeStyle(Color.navy) : AnyShapeStyle(.quaternary)))
      .scaleEffect(configuration.isPressed ? 0.9 : 1)
      .opacity(configuration.isPressed ? 0.8 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

struct SwitchRow: View {
  var title: String
  var detail: String?
  @Binding var isOn: Bool

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 1) {
        Text(title).font(.system(size: 13))
        if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
      }
      Spacer(minLength: 0)
      Toggle(title, isOn: $isOn).labelsHidden()
        .toggleStyle(.switch).controlSize(.mini).tint(.tangerine)
    }
  }
}
