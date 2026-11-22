// Which buttons a screen's row offers (#25). Plain logic, tested in `make test`.
//
// Disconnect (macOS treats the screen as unplugged and moves its windows) is its own button on
// monitor rows, beside Turn off. Never on the MacBook, not even greyed out: macOS would switch off
// its keyboard and trackpad. A disconnected screen offers Reconnect; a turned-off one, Turn on.

enum RowButtons {
  enum Kind: Equatable { case disconnect, turnOff, turnOn, reconnect }

  /// The row's buttons, left to right.
  static func buttons(isBuiltin: Bool, turnedOff: Bool, disconnected: Bool) -> [Kind] {
    if disconnected { return [.reconnect] }
    if turnedOff { return [.turnOn] }
    return isBuiltin ? [.turnOff] : [.disconnect, .turnOff]
  }
}
