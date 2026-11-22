// Checks which pointer a control in the menu shows (Sources/Pointer.swift).
// `make test` builds it with that one source; touches no display.

import Foundation

var failures = 0
func expect(_ actual: Pointer, _ expected: Pointer, _ what: String) {
  if actual == expected { print("ok    \(what)") } else {
    failures += 1
    print("FAIL  \(what): got \(actual), expected \(expected)")
  }
}

expect(Pointer.over(clickable: true, enabled: true), .hand,
       "a pill, switch, slider, link or Quit you can click shows the pointing hand")
expect(Pointer.over(clickable: true, enabled: false), .arrow,
       "Turn off on the only screen that's on can't be clicked: the arrow stays")
expect(Pointer.over(clickable: false, enabled: true), .arrow,
       "plain text keeps the arrow")
expect(Pointer.over(clickable: false, enabled: false), .arrow,
       "disabled plain text keeps the arrow")

if failures > 0 { print("\(failures) failed"); exit(1) }
print("all passed")
