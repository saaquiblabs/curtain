// Checks which buttons each screen's row offers (#25, Sources/RowButtons.swift).
// `make test` builds it with that one source; touches no display.

import Foundation

var failures = 0
func expect(_ actual: [RowButtons.Kind], _ expected: [RowButtons.Kind], _ what: String) {
  if actual == expected { print("ok    \(what)") } else {
    failures += 1
    print("FAIL  \(what): got \(actual), expected \(expected)")
  }
}

expect(RowButtons.buttons(isBuiltin: false, turnedOff: false, disconnected: false), [.disconnect, .turnOff],
       "a monitor that's on: Disconnect beside Turn off")
expect(RowButtons.buttons(isBuiltin: true, turnedOff: false, disconnected: false), [.turnOff],
       "the MacBook never gets Disconnect, not even greyed out")
expect(RowButtons.buttons(isBuiltin: false, turnedOff: false, disconnected: true), [.reconnect],
       "a disconnected monitor offers Reconnect")
expect(RowButtons.buttons(isBuiltin: false, turnedOff: true, disconnected: false), [.turnOn],
       "a turned-off monitor offers Turn on")
expect(RowButtons.buttons(isBuiltin: true, turnedOff: true, disconnected: false), [.turnOn],
       "a turned-off MacBook offers Turn on")

if failures > 0 { print("\(failures) failed"); exit(1) }
print("all passed")
