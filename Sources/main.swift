// Curtain: brightness for every screen, and a curtain to switch any of them off.
// A Saaquib Labs tool. MIT. Display code ported from MonitorControl (see NOTICE).

import AppKit
import Combine
import SwiftUI

let version = "0.4.0"

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem!
  private var watcher: AnyCancellable?
  private var panel: MenuPanel!
  private var outsideClicks: Any?
  private var escapeKey: Any?
  private let presence = MenuPresence()
  private var toggle = MenuToggle()
  private var isOpen = false

  func applicationDidFinishLaunching(_: Notification) {
    Fonts.register(from: Bundle.main.resourceURL?.appendingPathComponent("Fonts")) // before the menu first draws
    Screens.shared.start()
    Keys.shared.start()
    panel = makePanel()
    closeWhenMovingOn()

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.button?.action = #selector(toggleMenu)
    statusItem.button?.target = self
    watcher = Screens.shared.$all.receive(on: RunLoop.main).sink { [weak self] all in
      let drawn = all.contains(where: \.isOff)
      let image = NSImage(systemSymbolName: drawn ? "curtains.closed" : "curtains.open",
                          accessibilityDescription: Wording.menuBarIcon(off: all.filter(\.isOff).count, total: all.count))
      image?.isTemplate = true
      self?.statusItem.button?.image = image
      self?.leaveTurnedOffScreen()
    }
    // `--show` opens the menu at launch: for screenshots, and for menu bars so full that the
    // icon is hidden.
    if CommandLine.arguments.contains("--show") {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.openMenu() }
    }
  }

  private func makePanel() -> MenuPanel {
    let panel = MenuPanel.make(screens: .shared, keys: .shared, presence: presence)
    // Content grows or shrinks (a notice appears, a row goes): keep the top edge under the menu bar.
    NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: panel, queue: .main) { [weak self] _ in
      self?.place()
    }
    return panel
  }

  /// Like a macOS menu, it closes when you move on: focus goes to another window, another app
  /// comes forward, or you switch Space. (Mission Control posts nothing we can hear; the panel
  /// hides during it and closes once you pick a window, which brings another app forward.)
  private func closeWhenMovingOn() {
    NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
      self?.closeMenu(onItsOwn: true)
    }
    let workspace = NSWorkspace.shared.notificationCenter
    workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
      let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
      if app?.processIdentifier != ProcessInfo.processInfo.processIdentifier { self?.closeMenu(onItsOwn: true) }
    }
    workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
      self?.closeMenu(onItsOwn: true)
    }
  }

  /// Where the menu was opened: under the click (the icon may sit in a menu bar manager's own
  /// bar, so its reported position can't be trusted), or the top right without a click.
  private var anchor: NSPoint?

  /// The display the menu moved to because the screen it was on got turned off (#8). It stays
  /// there, top right under the menu bar, until the menu next opens.
  private var refuge: CGDirectDisplayID?

  /// Just under the menu bar, centred on the anchor, kept inside the screen. Never on a screen
  /// that's turned off: its black cover sits above everything, this menu included, so the menu
  /// goes to a screen that's on, where that row reads Off with Turn on ready (#8). An open menu
  /// that moves fades in there, and the pointer, left invisible on the black screen, jumps to it.
  ///
  /// The move is handled here, whoever calls: turning a screen off can also resize the menu (a
  /// software-dimmed monitor's row loses its "Dimmed by Curtain" line), and that resize places
  /// the menu before the screens change is heard. Checked only there, the pointer stayed behind
  /// on the black Lenovo (#29).
  private func place() {
    let size = panel.frame.size
    let topRight = NSPoint(x: CGFloat.greatestFiniteMagnitude, y: 0)
    let underClick = anchor.flatMap { click in NSScreen.screens.first { $0.frame.minX <= click.x && click.x <= $0.frame.maxX } }
    var screen = refuge.flatMap(Screens.nsScreen) ?? underClick ?? NSScreen.main
    var point = refuge == nil ? anchor ?? topRight : topRight
    let screensOn = Screens.shared.all.filter { !$0.isOff }.map(\.id)
    let pointerOn = Screens.shared.screenUnderPointer()?.id
    var moved = false
    if let target = MenuRefuge.destination(menuOn: screen?.displayID, screensOn: screensOn, pointerOn: pointerOn,
                                           menuBarOn: NSScreen.screens.first?.displayID),
       let onScreen = Screens.nsScreen(target) {
      refuge = target
      screen = onScreen
      point = topRight
      moved = true
    }
    guard let visible = screen?.visibleFrame else { return }
    let x = min(max(point.x - size.width / 2, visible.minX + 8), visible.maxX - size.width - 8)
    panel.setFrameTopLeftPoint(NSPoint(x: x, y: visible.maxY - 6))
    guard isOpen, moved else { return }
    panel.alphaValue = 0
    fadeIn()
    if MenuRefuge.pointerFollows(menuMoved: moved, pointerOn: pointerOn, screensOn: screensOn) { movePointer(to: panel.frame) }
  }

  /// Screens changed: an open menu on a screen that was just turned off moves (place).
  private func leaveTurnedOffScreen() {
    guard isOpen else { return }
    place()
  }

  /// Puts the pointer in the middle of `frame` (AppKit coordinates, origin bottom left of the
  /// main screen; the pointer is placed in Core Graphics ones, origin top left).
  private func movePointer(to frame: NSRect) {
    guard let mainHeight = NSScreen.screens.first?.frame.maxY else { return }
    CGWarpMouseCursorPosition(CGPoint(x: frame.midX, y: mainHeight - frame.midY))
    CGAssociateMouseAndMouseCursorPosition(1) // no pause before the pointer moves again
  }

  /// Fades the menu in, and slides it to `settled` if given (not with Reduce Motion).
  private func fadeIn(to settled: NSRect? = nil) {
    NSAnimationContext.runAnimationGroup { context in
      context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? Theme.Motion.reducedOpen : Theme.Motion.open
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      panel.animator().alphaValue = 1
      if let settled { panel.animator().setFrame(settled, display: true) }
    }
  }

  @objc private func toggleMenu() {
    switch toggle.iconClicked(isOpen: isOpen, at: ProcessInfo.processInfo.systemUptime) {
    case .open: openMenu(at: NSEvent.mouseLocation)
    case .close: closeMenu()
    case .ignore: break
    }
  }

  private func openMenu(at point: NSPoint? = nil) {
    anchor = point
    refuge = nil
    Screens.shared.notice = nil
    panel.fit()
    place()
    // Fades in, drifting down into place (just the fade with Reduce Motion).
    let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    let settled = panel.frame
    if !reduceMotion { panel.setFrame(settled.offsetBy(dx: 0, dy: Theme.Motion.openDrift), display: false) }
    panel.alphaValue = 0
    presence.shown = false
    isOpen = true
    panel.ignoresMouseEvents = false
    panel.makeKeyAndOrderFront(nil)
    DispatchQueue.main.async { withAnimation(Theme.Motion.openContent) { self.presence.shown = true } }
    fadeIn(to: reduceMotion ? nil : settled)
    outsideClicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
      self?.closeMenu(onItsOwn: true)
    }
    escapeKey = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      if event.keyCode == 53 { self?.closeMenu(); return nil } // Esc
      return event
    }
  }

  /// `onItsOwn`: closed by something other than the icon (outside click, focus, app or Space), so
  /// an icon click arriving right after is the one that caused it, not a request to reopen.
  private func closeMenu(onItsOwn: Bool = false) {
    // Ordering the panel out takes its focus, which calls back here: close only once.
    guard isOpen else { return }
    isOpen = false
    if onItsOwn { toggle.closedOnItsOwn(at: ProcessInfo.processInfo.systemUptime) }
    if let outsideClicks { NSEvent.removeMonitor(outsideClicks) }
    if let escapeKey { NSEvent.removeMonitor(escapeKey) }
    outsideClicks = nil; escapeKey = nil
    // Fades out, rising a touch, its content going soft (just a quicker fade with Reduce Motion);
    // ordered out once the fade ends, unless it was opened again meanwhile.
    let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    panel.ignoresMouseEvents = true
    withAnimation(Theme.Motion.closeContent) { presence.shown = false }
    NSAnimationContext.runAnimationGroup({ context in
      context.duration = reduceMotion ? Theme.Motion.reducedClose : Theme.Motion.close
      context.timingFunction = CAMediaTimingFunction(name: .easeIn)
      panel.animator().alphaValue = 0
      if !reduceMotion { panel.animator().setFrame(panel.frame.offsetBy(dx: 0, dy: Theme.Motion.closeDrift), display: true) }
    }, completionHandler: { [weak self] in
      guard let self, !self.isOpen else { return }
      self.panel.orderOut(nil)
    })
  }

  /// Quit, logout or restart: every screen back on, backlights and colours restored.
  func applicationWillTerminate(_: Notification) {
    Screens.shared.restoreEverything()
  }
}

// Being stopped by a signal (pkill, `brew services stop`) skips applicationWillTerminate, so
// catch those signals too and restore the screens before exiting.
var signalSources: [DispatchSourceSignal] = []
for sig in [SIGTERM, SIGINT, SIGHUP] {
  signal(sig, SIG_IGN)
  let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
  source.setEventHandler { Screens.shared.restoreEverything(); exit(0) }
  source.resume()
  signalSources.append(source)
}

if CommandLine.arguments.contains("--version") {
  print("curtain \(version)")
  exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
