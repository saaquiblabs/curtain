import Foundation

/// The Turn back on banner (#27): after Turn off (the button or ⌃⌥C), a small banner floats on
/// the screen you're on for about 6 s, even if the menu closes, with a button to undo it.
/// This is where it goes, what it names and when it goes; Sources/Banner.swift draws it.
enum TurnBackOn {
  /// How long it shows on its own.
  static let seconds: TimeInterval = 6
  /// How long it stays after the pointer leaves it, if that's later.
  static let afterPointerLeaves: TimeInterval = 2

  /// The display it shows on, or nil for none: the one under the pointer if it's on, then the
  /// one with the main menu bar, then any screen that's on (like MenuRefuge).
  static func screen(pointerOn: UInt32?, screensOn: [UInt32], menuBarOn: UInt32?) -> UInt32? {
    for preferred in [pointerOn, menuBarOn] {
      if let preferred, screensOn.contains(preferred) { return preferred }
    }
    return screensOn.first
  }

  /// The screens it names, which Turn back on brings back: the ones just turned off, plus any the
  /// banner already showing named that are still off.
  static func named(showing: [UInt32], justOff: [UInt32], stillOff: [UInt32]) -> [UInt32] {
    var names = showing.filter(stillOff.contains)
    for id in justOff where !names.contains(id) { names.append(id) }
    return names
  }

  /// When it goes if nothing else ends it: 6 s after it showed, or 2 s after the pointer left it
  /// if that's later.
  static func hidesAt(shownAt: TimeInterval, pointerLeftAt: TimeInterval?) -> TimeInterval {
    max(shownAt + seconds, (pointerLeftAt ?? -.infinity) + afterPointerLeaves)
  }

  /// Whether it's still showing. It stays while the pointer is on it, so it can't fade out under
  /// a click, and goes at once when none of its screens is off any more.
  static func showing(shownAt: TimeInterval, now: TimeInterval, pointerLeftAt: TimeInterval?,
                      pointerOnIt: Bool, stillOff: Int) -> Bool {
    guard stillOff > 0 else { return false }
    return pointerOnIt || now < hidesAt(shownAt: shownAt, pointerLeftAt: pointerLeftAt)
  }
}
