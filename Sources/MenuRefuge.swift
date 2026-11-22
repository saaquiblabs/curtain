import Foundation

/// Where Curtain's menu goes when the screen it's open on is turned off (#8).
///
/// Turn off covers a screen with a black window above everything, Curtain's menu included. Left
/// there, the menu (and its Turn on button) would be hidden behind the black. So the menu moves,
/// still open, to a screen that's on, where that row now reads Off with Turn on ready.
enum MenuRefuge {
  /// The display to move the menu to, or nil to leave it where it is.
  /// - menuOn: the display the menu is on (nil if unknown).
  /// - screensOn: displays you can still see, in Curtain's order.
  /// - pointerOn / menuBarOn: the display under the pointer, and the one with the main menu bar.
  static func destination(menuOn: UInt32?, screensOn: [UInt32], pointerOn: UInt32?, menuBarOn: UInt32?) -> UInt32? {
    if let menuOn, screensOn.contains(menuOn) { return nil }
    // Where you're looking, then where macOS's menu bar is, then any screen that's on.
    for preferred in [pointerOn, menuBarOn] {
      if let preferred, screensOn.contains(preferred) { return preferred }
    }
    return screensOn.first
  }

  /// Whether the pointer jumps to the menu after the menu moved: only when it was left on a screen
  /// you can't see (or on no known screen), where you'd lose it (#8, #29).
  static func pointerFollows(menuMoved: Bool, pointerOn: UInt32?, screensOn: [UInt32]) -> Bool {
    guard menuMoved else { return false }
    guard let pointerOn else { return true }
    return !screensOn.contains(pointerOn)
  }
}
