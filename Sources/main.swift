// Curtain: brightness for every screen, and a curtain to switch any of them off.
// A Saaquib Labs tool. MIT. Display code ported from MonitorControl (see NOTICE).

import AppKit
import Combine
import SwiftUI

let version = "0.2.1"

/// Curtain's menu: a panel that always opens fully on screen, just under the menu bar.
/// (NSPopover places itself off-screen when a menu bar manager has moved our icon.)
final class MenuPanel: NSPanel {
  override var canBecomeKey: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem!
  private var watcher: AnyCancellable?
  private var panel: MenuPanel!
  private var outsideClicks: Any?
  private var escapeKey: Any?

  func applicationDidFinishLaunching(_: Notification) {
    Screens.shared.start()
    Keys.shared.start()
    panel = makePanel()

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.button?.action = #selector(toggleMenu)
    statusItem.button?.target = self
    watcher = Screens.shared.$all.receive(on: RunLoop.main).sink { [weak self] all in
      let drawn = all.contains(where: \.isOff)
      let image = NSImage(systemSymbolName: drawn ? "curtains.closed" : "curtains.open", accessibilityDescription: "Curtain")
      image?.isTemplate = true
      self?.statusItem.button?.image = image
    }
    // `--show` opens the menu at launch: for screenshots, and for menu bars so full that the
    // icon is hidden.
    if CommandLine.arguments.contains("--show") {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.openMenu() }
    }
  }

  private func makePanel() -> MenuPanel {
    let controller = NSHostingController(rootView: PopoverView(screens: .shared, keys: .shared))
    controller.sizingOptions = .preferredContentSize
    let effect = Theme.glass(blending: .behindWindow)
    let host = controller.view
    host.translatesAutoresizingMaskIntoConstraints = false
    effect.addSubview(host)
    NSLayoutConstraint.activate([
      host.leadingAnchor.constraint(equalTo: effect.leadingAnchor), host.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
      host.topAnchor.constraint(equalTo: effect.topAnchor), host.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
    ])
    let panel = MenuPanel(contentRect: NSRect(origin: .zero, size: host.fittingSize),
                          styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.level = .popUpMenu
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    panel.isReleasedWhenClosed = false
    panel.contentView = effect
    // Content grows (a notice appears): keep the top edge under the menu bar.
    NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: panel, queue: .main) { [weak self] _ in
      self?.place()
    }
    return panel
  }

  /// Where the menu was opened: under the click (the icon may sit in a menu bar manager's own
  /// bar, so its reported position can't be trusted), or the top right without a click.
  private var anchor: NSPoint?

  /// Just under the menu bar, centred on the anchor, kept inside the screen.
  private func place() {
    let size = panel.frame.size
    let point = anchor ?? NSPoint(x: CGFloat.greatestFiniteMagnitude, y: 0)
    let screen = NSScreen.screens.first { $0.frame.minX <= point.x && point.x <= $0.frame.maxX && anchor != nil } ?? NSScreen.main
    guard let visible = screen?.visibleFrame else { return }
    let x = min(max(point.x - size.width / 2, visible.minX + 8), visible.maxX - size.width - 8)
    panel.setFrameTopLeftPoint(NSPoint(x: x, y: visible.maxY - 6))
  }

  @objc private func toggleMenu() {
    panel.isVisible ? closeMenu() : openMenu(at: NSEvent.mouseLocation)
  }

  private func openMenu(at point: NSPoint? = nil) {
    anchor = point
    Screens.shared.notice = nil
    place()
    // Fades in, drifting down into place (just the fade with Reduce Motion).
    let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    let settled = panel.frame
    if !reduceMotion { panel.setFrame(settled.offsetBy(dx: 0, dy: Theme.Motion.openDrift), display: false) }
    panel.alphaValue = 0
    panel.makeKeyAndOrderFront(nil)
    NSAnimationContext.runAnimationGroup { context in
      context.duration = reduceMotion ? Theme.Motion.reducedOpen : Theme.Motion.open
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      panel.animator().alphaValue = 1
      if !reduceMotion { panel.animator().setFrame(settled, display: true) }
    }
    outsideClicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
      self?.closeMenu()
    }
    escapeKey = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      if event.keyCode == 53 { self?.closeMenu(); return nil } // Esc
      return event
    }
  }

  private func closeMenu() {
    if let outsideClicks { NSEvent.removeMonitor(outsideClicks) }
    if let escapeKey { NSEvent.removeMonitor(escapeKey) }
    outsideClicks = nil; escapeKey = nil
    panel.orderOut(nil)
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
