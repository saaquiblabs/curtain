import Foundation

/// What a click on Curtain's menu bar icon does.
///
/// The menu also closes on its own: an outside click, another app or Space, losing focus. A click
/// on the icon can cause one of those first. A menu bar manager draws the icon in its own bar, so
/// the click reaches another app (an outside click) before it reaches our icon, and clicking the
/// icon takes focus from the menu. Without care that click closes the menu and then reopens it.
/// So the first icon click shortly after the menu closed on its own is the one that closed it.
struct MenuToggle {
  enum Action: Equatable { case open, close, ignore }

  /// How soon after the menu closes on its own an icon click is taken as the click that closed it.
  static let closingClickWindow: TimeInterval = 0.5

  private var closedOnItsOwnAt: TimeInterval?

  /// The menu closed without its icon being clicked. `time` in seconds (e.g. system uptime).
  mutating func closedOnItsOwn(at time: TimeInterval) {
    closedOnItsOwnAt = time
  }

  mutating func iconClicked(isOpen: Bool, at time: TimeInterval) -> Action {
    defer { closedOnItsOwnAt = nil }
    if isOpen { return .close }
    if let closed = closedOnItsOwnAt, time - closed <= Self.closingClickWindow { return .ignore }
    return .open
  }
}
