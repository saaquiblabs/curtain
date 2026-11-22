// Which pointer the menu shows over a control (#10). Plain logic, tested in `make test`; UI.swift's
// `.clickable()` turns it into the real cursor.

enum Pointer: Equatable {
  case arrow, hand

  static func over(clickable: Bool, enabled: Bool) -> Pointer {
    clickable && enabled ? .hand : .arrow
  }
}
