import CoreGraphics
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

  /// Whether the pointer jumps to the menu after Turn off moved it: only when it was left on a
  /// screen you can't see (or on no known screen), where you'd lose it (#8, #29). (Disconnect
  /// keeps the pointer's spot on the menu instead: `pointer(offset:menu:screen:)`, #25.)
  static func pointerFollows(menuMoved: Bool, pointerOn: UInt32?, screensOn: [UInt32]) -> Bool {
    guard menuMoved else { return false }
    guard let pointerOn else { return true }
    return !screensOn.contains(pointerOn)
  }

  /// How far the menu's middle sits from the right edge of its screen when Disconnect takes that
  /// screen away (#25). The menu opens under Curtain's icon, and macOS draws the menu bar icons the
  /// same distance from the right edge on every screen, so this distance is where the icon is,
  /// whatever the screen's width. (A fraction across the screen, the first take, put a menu opened
  /// near the right of a wide monitor at the far right of the MacBook, away from the icon: owner,
  /// 2026-11-25.) Kept as a distance, not a point: macOS moves every screen's coordinates when the
  /// main screen goes. Screen as (minX, width) of its visible area.
  static func fromRight(midX: Double, of screen: (minX: Double, width: Double)) -> Double {
    min(max(screen.minX + screen.width - midX, 0), screen.width)
  }

  /// The menu's middle on another screen, the same distance from its right edge: under the icon
  /// there too. Kept on that screen.
  static func underIcon(fromRight: Double, on screen: (minX: Double, width: Double)) -> Double {
    min(max(screen.minX + screen.width - fromRight, screen.minX), screen.minX + screen.width)
  }

  /// Where the pointer goes so it keeps its spot on the menu after Disconnect or Reconnect moved
  /// the menu (#25, owner's pick): the same offset from the menu's top left, kept on the screen.
  /// AppKit coordinates (y grows upwards); `offset.y` is measured down from the menu's top.
  static func pointer(offset: CGPoint, menu: CGRect, screen: CGRect) -> CGPoint {
    CGPoint(x: min(max(menu.minX + offset.x, screen.minX), screen.maxX - 1),
            y: min(max(menu.maxY - offset.y, screen.minY), screen.maxY - 1))
  }
}
