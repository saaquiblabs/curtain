// The window Curtain's menu lives in. Kept out of main.swift so a test can build the real panel
// from made-up screens (Tests/menu-panel) without starting the app or touching a display.

import AppKit
import SwiftUI

/// Curtain's menu: a panel that always opens fully on screen, just under the menu bar.
/// (NSPopover places itself off-screen when a menu bar manager has moved our icon.)
final class MenuPanel: NSPanel {
  override var canBecomeKey: Bool { true }

  /// The SwiftUI menu inside the glass, and the controller that sizes it. The panel must keep the
  /// controller: freed, its view still grows with the menu but never shrinks, so after a monitor
  /// went the panel kept its two-screen height, bare glass above and below (#21).
  private var host: NSView!
  private var controller: NSHostingController<AnyView>!

  /// The menu in Theme's glass, sized to fit it.
  static func make(showing menu: some View, presence: MenuPresence) -> MenuPanel {
    let controller = NSHostingController(rootView: AnyView(menu))
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
    panel.host = host
    panel.controller = controller
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.level = .popUpMenu
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    panel.isReleasedWhenClosed = false
    panel.contentView = effect
    // The panel fits the menu as its content changes: a notice appears, a row goes (#4).
    presence.resized = { [weak panel] _ in panel?.fit() }
    return panel
  }

  /// Makes the panel exactly as tall and wide as the menu's content. The kept controller already
  /// does this as the content changes, open or closed; the app also calls it on every open, so a
  /// size change SwiftUI never reported can't outlive a reopen.
  func fit() {
    host.layoutSubtreeIfNeeded()
    let size = host.fittingSize
    guard size.height > 0, contentLayoutRect.size != size else { return }
    setContentSize(size)
  }
}
