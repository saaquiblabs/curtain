// The Turn back on banner (#27): after Turn off, a small banner floats for about 6 s on the
// screen you're on, even if the menu closes: "L27h-4A is off · Turn back on · ⌃⌥C". Where it goes
// and when it goes is Sources/TurnBackOn.swift; its look comes from Theme like the menu's.

import AppKit
import Combine
import SwiftUI

/// What the banner shows. Drawn by `make renders` from made-up names too.
struct BannerView: View {
  var line: String
  var turnBackOn: () -> Void = {}
  /// The pointer came onto the banner (true) or left it.
  var hovered: (Bool) -> Void = { _ in }

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "curtains.closed")
        .font(Theme.Font.icon).foregroundStyle(Theme.accent)
        .accessibilityHidden(true)
      Text(line).font(Theme.Font.title).foregroundStyle(Theme.text).lineLimit(1)
      Button(action: turnBackOn) {
        Label("Turn back on", systemImage: "power")
          .font(Theme.Font.button)
          .labelStyle(.titleAndIcon)
          .padding(.horizontal, 9).padding(.vertical, 4)
          .fixedSize()
      }
      .buttonStyle(PillStyle(prominent: true))
      .accessibilityHint(Wording.spokenKeys(Keys.shortcutLabel) + " turns every screen back on too")
      HStack(spacing: 2) {
        ForEach(Array(Keys.shortcutLabel.enumerated()), id: \.offset) { Keycap(symbol: String($0.element)) }
      }
      .font(Theme.Font.caption).foregroundStyle(Theme.textSecondary)
      .accessibilityHidden(true) // the button's hint says it
    }
    .padding(.leading, 14).padding(.trailing, 12).padding(.vertical, 10)
    .background(MenuSurface())
    .fixedSize()
    .onHover(perform: hovered)
  }
}

/// The banner's window and its life: shown by `Screens.didTurnOff`, gone after `TurnBackOn`'s
/// time, or at once when every screen it names is back on.
final class TurnBackOnBanner {
  private let screens: Screens
  private var panel: NSPanel?
  /// The screens it names, which Turn back on brings back.
  private var named: [CGDirectDisplayID] = []
  private var shownAt: TimeInterval = 0
  private var pointerLeftAt: TimeInterval?
  private var pointerOnIt = false
  private var timer: Timer?
  private var watcher: AnyCancellable?
  private var hiding = false

  init(screens: Screens) {
    self.screens = screens
    // A screen turned back on from the menu or ⌃⌥C, or the banner's screen gone: check again.
    watcher = screens.$all.receive(on: RunLoop.main).sink { [weak self] _ in self?.check() }
  }

  private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
  private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
  private var isShowing: Bool { panel != nil && !hiding }

  /// Turn off just turned `ids` off: show the banner on the screen you're on.
  func show(justOff ids: [CGDirectDisplayID]) {
    let stillOff = screens.all.filter(\.blackedOut).map(\.id)
    named = TurnBackOn.named(showing: isShowing ? named : [], justOff: ids, stillOff: stillOff)
    let screensOn = screens.all.filter { !$0.isOff }.map(\.id)
    guard let target = TurnBackOn.screen(pointerOn: screens.screenUnderPointer()?.id, screensOn: screensOn,
                                         menuBarOn: NSScreen.screens.first?.displayID),
          let onScreen = Screens.nsScreen(target) else { return }
    let names = named.compactMap { id in screens.all.first { $0.id == id }?.name }
    let view = BannerView(line: Wording.bannerLine(names: names),
                          turnBackOn: { [weak self] in self?.turnBackOn() },
                          hovered: { [weak self] in self?.pointer(on: $0) })

    let panel = self.panel ?? Self.makePanel()
    (panel.contentView?.subviews.first as? BannerHost)?.removeFromSuperview()
    let host = BannerHost(rootView: view)
    let size = host.fittingSize
    let effect = panel.contentView!
    host.frame = NSRect(origin: .zero, size: size)
    effect.addSubview(host)
    let visible = onScreen.visibleFrame
    let settled = NSRect(x: visible.midX - size.width / 2, y: visible.minY + Theme.Size.bannerLift,
                         width: size.width, height: size.height)
    let wasShowing = isShowing
    self.panel = panel
    hiding = false
    shownAt = now; pointerLeftAt = nil; pointerOnIt = false
    if wasShowing {
      panel.setFrame(settled, display: true) // a second Turn off: the same banner, its words updated
      panel.alphaValue = 1
    } else {
      panel.setFrame(reduceMotion ? settled : settled.offsetBy(dx: 0, dy: -Theme.Motion.bannerRise), display: false)
      panel.alphaValue = 0
      panel.orderFrontRegardless()
      NSAnimationContext.runAnimationGroup { context in
        context.duration = reduceMotion ? Theme.Motion.reducedOpen : Theme.Motion.open
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        panel.animator().alphaValue = 1
        if !reduceMotion { panel.animator().setFrame(settled, display: true) }
      }
    }
    NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
      .announcement: Wording.bannerSpoken(names: names, keys: Keys.shortcutLabel),
      .priority: NSAccessibilityPriorityLevel.high.rawValue,
    ])
    check()
  }

  private func turnBackOn() {
    for id in named { if let screen = screens.all.first(where: { $0.id == id }) { screens.setQuickOff(screen, off: false) } }
    hide()
  }

  private func pointer(on: Bool) {
    pointerOnIt = on
    if !on { pointerLeftAt = now }
    check()
  }

  /// Hides it when its time is up, its screens are back on, or its screen went; otherwise checks
  /// again when its time would be up.
  private func check() {
    guard isShowing, let panel else { return }
    timer?.invalidate(); timer = nil
    let stillOff = named.filter { id in screens.all.contains { $0.id == id && $0.blackedOut } }.count
    guard panel.screen != nil,
          TurnBackOn.showing(shownAt: shownAt, now: now, pointerLeftAt: pointerLeftAt,
                             pointerOnIt: pointerOnIt, stillOff: stillOff) else { return hide() }
    guard !pointerOnIt else { return } // leaving it checks again
    let wait = TurnBackOn.hidesAt(shownAt: shownAt, pointerLeftAt: pointerLeftAt) - now
    let timer = Timer(timeInterval: max(wait, 0.05), repeats: false) { [weak self] _ in self?.check() }
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }

  /// Fades out, sinking back a touch (just the fade with Reduce Motion).
  private func hide() {
    guard isShowing, let panel else { return }
    hiding = true
    timer?.invalidate(); timer = nil
    NSAnimationContext.runAnimationGroup({ context in
      context.duration = reduceMotion ? Theme.Motion.reducedClose : Theme.Motion.close
      context.timingFunction = CAMediaTimingFunction(name: .easeIn)
      panel.animator().alphaValue = 0
      if !reduceMotion { panel.animator().setFrame(panel.frame.offsetBy(dx: 0, dy: -Theme.Motion.bannerRise), display: true) }
    }, completionHandler: { [weak self] in
      guard let self, self.hiding else { return } // shown again meanwhile
      panel.orderOut(nil)
      self.panel = nil
      self.hiding = false
    })
  }

  /// A floating panel that never takes focus, so the menu stays open and your app keeps the keys,
  /// on every Space and over full-screen apps, in the menu's glass.
  private static func makePanel() -> NSPanel {
    let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.level = .popUpMenu
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    panel.isReleasedWhenClosed = false
    panel.hidesOnDeactivate = false
    panel.contentView = Theme.glass(blending: .behindWindow)
    return panel
  }
}

/// The banner's SwiftUI view, taking the first click: the banner never becomes the key window,
/// and Turn back on must work on that first click.
private final class BannerHost: NSHostingView<BannerView> {
  override func acceptsFirstMouse(for _: NSEvent?) -> Bool { true }
}
