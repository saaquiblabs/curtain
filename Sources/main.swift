// Curtain: brightness for every screen, and a curtain to switch any of them off.
// A Saaquib Labs tool. MIT. Display code ported from MonitorControl (see NOTICE).

import AppKit
import Combine
import SwiftUI

let version = "0.1.0"

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem!
  private let popover = NSPopover()
  private var watcher: AnyCancellable?
  private static var quitting = false

  func applicationDidFinishLaunching(_: Notification) {
    Screens.shared.start()
    Keys.shared.start()

    popover.behavior = .transient
    popover.animates = true
    popover.contentViewController = NSHostingController(rootView: PopoverView())

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.button?.action = #selector(togglePopover)
    statusItem.button?.target = self
    watcher = Screens.shared.$all.receive(on: RunLoop.main).sink { [weak self] all in
      let drawn = all.contains(where: \.curtained)
      let image = NSImage(systemSymbolName: drawn ? "curtains.closed" : "curtains.open", accessibilityDescription: "Curtain")
      image?.isTemplate = true
      self?.statusItem.button?.image = image
    }
    // `--show` also opens the menu's content in a floating panel: for screenshots, and for menu
    // bars so full that macOS hides the icon.
    if CommandLine.arguments.contains("--show") { showPanel() }
  }

  private var panel: NSPanel?

  private func showPanel() {
    let host = NSHostingView(rootView: PopoverView())
    let effect = NSVisualEffectView()
    effect.material = .popover
    effect.state = .active
    effect.addSubview(host)
    host.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      host.leadingAnchor.constraint(equalTo: effect.leadingAnchor), host.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
      host.topAnchor.constraint(equalTo: effect.topAnchor), host.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
    ])
    let panel = NSPanel(contentRect: NSRect(origin: .zero, size: host.fittingSize),
                        styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.isMovableByWindowBackground = true
    panel.level = .floating
    panel.contentView = effect
    panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
    panel.standardWindowButton(.zoomButton)?.isHidden = true
    panel.center()
    panel.orderFrontRegardless()
    self.panel = panel
  }

  @objc private func togglePopover() {
    guard let button = statusItem.button else { return }
    if popover.isShown {
      popover.performClose(nil)
    } else {
      Screens.shared.notice = nil
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
      popover.contentViewController?.view.window?.makeKey()
    }
  }

  /// Quit from the menu: every screen back on and nothing remembered.
  static func quit() {
    quitting = true
    Screens.shared.restoreEverything(forget: true)
    NSApp.terminate(nil)
  }

  /// Logout, restart or being killed: screens back on, but curtains are remembered for next time.
  func applicationWillTerminate(_: Notification) {
    if !Self.quitting { Screens.shared.restoreEverything(forget: false) }
  }
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
