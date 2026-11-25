// The Turn back on banner (#27): after Turn off, a small banner floats for about 6 s on the
// screen you're on, even if the menu closes: "L27h-4A is off · Turn back on · ⌃⌥C · ×". Esc or the
// × closes it, and it can be dragged anywhere (owner, after the desk test). Where it goes and when
// it goes is Sources/TurnBackOn.swift; its look comes from Theme like the menu's.

import AppKit
import Combine
import SwiftUI

/// What the banner shows. Drawn by `make renders` from made-up names too.
struct BannerView: View {
  var line: String
  var turnBackOn: () -> Void = {}
  var close: () -> Void = {}
  /// The pointer came onto the banner (true) or left it.
  var hovered: (Bool) -> Void = { _ in }
  /// A drag on the banner: true while it moves, false when it's let go.
  var dragged: (Bool) -> Void = { _ in }

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
      .accessibilityHint(Wording.bannerHint(keys: Keys.shortcutLabel))
      ShortcutKeys()
        .font(Theme.Font.caption).foregroundStyle(Theme.textSecondary)
      .accessibilityHidden(true) // the button's hint says it
      Button(action: close) {
        Image(systemName: "xmark")
          .font(Theme.Font.caption.weight(.semibold))
          .padding(Theme.Size.bannerClosePadding)
      }
      .buttonStyle(PillStyle(prominent: false))
      .accessibilityLabel(Wording.bannerClose)
      .accessibilityHint(Wording.bannerCloseHint)
    }
    .padding(.leading, 14).padding(.trailing, 12).padding(.vertical, 10)
    .background(MenuSurface())
    .fixedSize()
    .onHover(perform: hovered)
    // Moved by NSEvent's pointer, not the gesture's points: those move with the window.
    .gesture(DragGesture(minimumDistance: 2).onChanged { _ in dragged(true) }.onEnded { _ in dragged(false) })
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
  /// The display it was put on, or dragged to.
  private var shownOn: CGDirectDisplayID?
  /// Where a drag started: the pointer and the banner's origin.
  private var dragFrom: (pointer: NSPoint, origin: NSPoint)?
  /// It was dragged: a second Turn off updates its words where it is.
  private var moved = false
  private var escMonitors: [Any] = []

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
    // Still fading out counts as showing: its screens stay named, so Turn back on brings them all.
    let stillOff = screens.all.filter(\.blackedOut).map(\.id)
    let named = TurnBackOn.named(showing: panel != nil ? self.named : [], justOff: ids, stillOff: stillOff)
    let names = named.compactMap { id in screens.all.first { $0.id == id }?.name }
    let screensOn = screens.all.filter { !$0.isOff }.map(\.id)
    guard !names.isEmpty,
          let target = TurnBackOn.screen(pointerOn: screens.screenUnderPointer()?.id, screensOn: screensOn,
                                         menuBarOn: NSScreen.screens.first?.displayID),
          let onScreen = Screens.nsScreen(target) else { return }
    self.named = named
    let view = BannerView(line: Wording.bannerLine(names: names),
                          turnBackOn: { [weak self] in self?.turnBackOn() },
                          close: { [weak self] in self?.hide() },
                          hovered: { [weak self] in self?.pointer(on: $0) },
                          dragged: { [weak self] in self?.drag($0) })

    // One view for the banner's life, its words swapped: a new view under a resting pointer would
    // never hear it arrive, and the banner would fade out under it.
    let panel = self.panel ?? Self.makePanel()
    let host: BannerHost
    if let shown = panel.contentView?.subviews.first as? BannerHost {
      host = shown
      host.rootView = view
    } else {
      host = BannerHost(rootView: view)
      panel.contentView!.addSubview(host)
    }
    let size = host.fittingSize
    host.frame = NSRect(origin: .zero, size: size)
    let visible = onScreen.visibleFrame
    let centred = NSRect(x: visible.midX - size.width / 2, y: visible.minY + Theme.Size.bannerLift,
                         width: size.width, height: size.height)
    let wasShowing = isShowing
    if !wasShowing { moved = false }
    let settled = wasShowing && moved
      ? NSRect(origin: NSPoint(x: panel.frame.midX - size.width / 2, y: panel.frame.minY), size: size)
      : centred
    if !(wasShowing && moved) { shownOn = target }
    self.panel = panel
    hiding = false
    shownAt = now; pointerLeftAt = nil
    pointerOnIt = wasShowing && settled.contains(NSEvent.mouseLocation)
    if wasShowing {
      panel.setFrame(settled, display: true) // a second Turn off: the same banner, its words updated
      panel.alphaValue = 1
    } else {
      panel.setFrame(reduceMotion ? settled : settled.offsetBy(dx: 0, dy: -Theme.Motion.bannerRise), display: false)
      panel.alphaValue = 0
      panel.orderFrontRegardless()
      watchEsc()
      NSAnimationContext.runAnimationGroup { context in
        context.duration = reduceMotion ? Theme.Motion.reducedOpen : Theme.Motion.open
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        panel.animator().alphaValue = 1
        if !reduceMotion { panel.animator().setFrame(settled, display: true) }
      }
    }
    NSAccessibility.post(element: panel, notification: .announcementRequested, userInfo: [
      .announcement: Wording.bannerSpoken(names: names, keys: Keys.shortcutLabel),
      .priority: NSAccessibilityPriorityLevel.high.rawValue,
    ])
    check()
  }

  private func turnBackOn() {
    for id in named { if let screen = screens.all.first(where: { $0.id == id }) { screens.setQuickOff(screen, off: false) } }
    hide()
  }

  /// Follows the pointer while dragged; it then belongs to the screen it was dropped on.
  private func drag(_ moving: Bool) {
    guard isShowing, let panel else { return }
    let pointer = NSEvent.mouseLocation
    if moving {
      let from = dragFrom ?? (pointer, panel.frame.origin)
      dragFrom = from
      moved = true
      panel.setFrameOrigin(NSPoint(x: from.origin.x + pointer.x - from.pointer.x,
                                   y: from.origin.y + pointer.y - from.pointer.y))
    } else {
      dragFrom = nil
    }
    shownOn = panel.screen?.displayID ?? shownOn
  }

  /// Esc closes it while it shows: heard in other apps with Accessibility (as the brightness keys
  /// are), and in Curtain's own menu always. It's only listened to, never taken from the app.
  private func watchEsc() {
    guard escMonitors.isEmpty else { return }
    let esc: (NSEvent) -> Bool = { event in
      event.keyCode == 53 && event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty
    }
    if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
      if esc(event) { self?.hide() }
    }) { escMonitors.append(global) }
    if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
      guard esc(event), self?.isShowing == true else { return event }
      self?.hide()
      return event // the menu hears Esc too
    }) { escMonitors.append(local) }
  }

  private func stopEsc() {
    escMonitors.forEach(NSEvent.removeMonitor)
    escMonitors = []
  }

  private func pointer(on: Bool) {
    pointerOnIt = on
    if !on { pointerLeftAt = now }
    check()
  }

  /// Hides it when its time is up, its screens are back on, or its screen went dark or away
  /// (macOS would carry it to another screen, somewhere off its place); otherwise checks again
  /// when its time would be up.
  private func check() {
    guard isShowing, let panel else { return }
    timer?.invalidate(); timer = nil
    let stillOff = named.filter { id in screens.all.contains { $0.id == id && $0.blackedOut } }.count
    guard let onScreen = panel.screen?.displayID, onScreen == shownOn,
          screens.all.contains(where: { $0.id == onScreen && !$0.isOff }),
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
    stopEsc()
    dragFrom = nil
    NSAnimationContext.runAnimationGroup({ context in
      context.duration = reduceMotion ? Theme.Motion.reducedClose : Theme.Motion.close
      context.timingFunction = CAMediaTimingFunction(name: .easeIn)
      panel.animator().alphaValue = 0
      if !reduceMotion { panel.animator().setFrame(panel.frame.offsetBy(dx: 0, dy: -Theme.Motion.bannerRise), display: true) }
    }, completionHandler: { [weak self] in
      guard let self, self.hiding else { return } // shown again meanwhile
      panel.orderOut(nil)
      self.moved = false
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
