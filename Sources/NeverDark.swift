// Curtain never leaves every screen dark (#29). Plain logic, tested in `make test`.
//
// Turn off and Unplug both refuse to darken the last screen you can see, but a screen can also
// leave on its own: a monitor's cable comes out, the lid closes. If what's left is all turned off
// or unplugged, every screen comes back on. Screens checks this after every change.

enum NeverDark {
  /// `screensOff`: whether each remaining screen is off (turned off or unplugged).
  static func mustTurnAllOn(screensOff: [Bool]) -> Bool {
    !screensOff.isEmpty && !screensOff.contains(false)
  }
}
