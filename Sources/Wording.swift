// What the menu says, and what VoiceOver says for what it shows (#6).

enum Wording {
  /// The header's line: "2 screens on", or "1 of 2 off".
  static func summary(off: Int, total: Int) -> String {
    off == 0 ? "\(total) screen\(total == 1 ? "" : "s") on" : "\(off) of \(total) off"
  }

  /// A shortcut's keycaps as words: "⌃⌥C" reads "Control Option C".
  static func spokenKeys(_ keys: String) -> String {
    let names: [Character: String] = ["⌃": "Control", "⌥": "Option", "⌘": "Command", "⇧": "Shift"]
    return keys.map { names[$0] ?? String($0) }.joined(separator: " ")
  }

  /// The menu bar icon's VoiceOver description. Its picture changes (open or closed curtain), so
  /// its words do too.
  static func menuBarIcon(off: Int, total: Int) -> String {
    "Curtain, " + (off == 0 ? summary(off: 0, total: total) : "\(off) of \(total) screens off")
  }

  /// A brightness slider's VoiceOver label, naming its screen.
  static func sliderLabel(screen: String) -> String {
    "\(screen) brightness"
  }

  /// The line under the desk map while a control is under the pointer, saying its result (#26).
  /// One short line each, so it fits under the map. (They were tooltips until 0.5.0.)
  static func turnOffLine(screen: String, onlyOneOn: Bool) -> String {
    onlyOneOn ? "\(screen) is the only screen on, so it stays on."
              : "Turns \(screen) black at once. Its windows stay on it."
  }

  /// `other`: a screen that stays on, where the windows go.
  static func disconnectLine(screen: String, other: String, onlyOneOn: Bool) -> String {
    onlyOneOn ? "\(screen) is the only screen on, so it stays connected."
              : "Disconnects \(screen); windows move to \(other), screens blink."
  }

  static func turnOnLine(screen: String) -> String { "Turns \(screen) back on, its windows as they were." }

  static func reconnectLine(screen: String) -> String { "Reconnects \(screen). Every screen blinks for a moment." }

  /// The slider: the brightness under the pointer, rounded like the slider's own percent.
  static func brightnessLine(screen: String, to value: Double) -> String {
    "Sets \(screen) to \(Int((value * 100).rounded()))%."
  }

  static let quitLine = "Quits Curtain; every screen comes back on."

  /// The line in place of the slider while a screen is off or disconnected.
  static func offLine(disconnected: Bool, other: String) -> String {
    disconnected ? "Disconnected. Its windows moved to \(other)." : "Off. Its windows are still there, hidden."
  }

  /// The Turn back on banner's line (#27): "L27h-4A is off", or "2 screens are off".
  static func bannerLine(names: [String]) -> String {
    names.count == 1 ? "\(names[0]) is off" : "\(names.count) screens are off"
  }

  /// What VoiceOver announces as the banner shows.
  static func bannerSpoken(names: [String], keys: String) -> String {
    "\(bannerLine(names: names)). Turn back on, or press \(spokenKeys(keys))."
  }

  /// What a screen's tile on the desk map shows.
  enum TileState: String { case on, off, disconnected }

  /// The desk map's VoiceOver line, its screens in reading order: "L27h-4A on, MacBook off" (#24).
  static func deskMap(_ screens: [(name: String, state: TileState)]) -> String {
    screens.map { "\($0.name) \($0.state.rawValue)" }.joined(separator: ", ")
  }
}
