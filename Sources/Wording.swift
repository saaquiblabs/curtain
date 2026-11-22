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

  /// What each row button says it does, under the pointer (#25). `other`: a screen that stays on.
  static func turnOffHelp(screen: String, onlyOneOn: Bool) -> String {
    onlyOneOn ? "\(screen) is the only screen on, so it stays on. Turn another screen on first."
              : "Turn \(screen) black instantly. Windows stay on it."
  }

  static func disconnectHelp(screen: String, other: String, onlyOneOn: Bool) -> String {
    onlyOneOn ? "\(screen) is the only screen on, so it stays connected. Turn another screen on first."
              : "Disconnect \(screen): macOS treats it as unplugged and moves its windows to \(other). Every screen blinks black for a moment."
  }

  static func turnOnHelp(screen: String) -> String { "Turn \(screen) back on" }

  static func reconnectHelp(screen: String) -> String {
    "Reconnect \(screen). Every screen blinks black for a moment."
  }

  /// The line in place of the slider while a screen is off or disconnected.
  static func offLine(disconnected: Bool, other: String) -> String {
    disconnected ? "Disconnected. Its windows moved to \(other)." : "Off. Its windows are still there, hidden."
  }

  /// What a screen's tile on the desk map shows.
  enum TileState: String { case on, off, disconnected }

  /// The desk map's VoiceOver line, its screens in reading order: "L27h-4A on, MacBook off" (#24).
  static func deskMap(_ screens: [(name: String, state: TileState)]) -> String {
    screens.map { "\($0.name) \($0.state.rawValue)" }.joined(separator: ", ")
  }
}
