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
}
