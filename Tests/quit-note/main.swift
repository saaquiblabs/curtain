// Checks when a screen's row says Curtain's dimming ends when Curtain quits (Sources/QuitNote.swift).
// `make test` builds it with that one source; touches no display.

import Foundation

var failures = 0
func expect(_ actual: Bool, _ expected: Bool, _ what: String) {
  if actual == expected { print("ok    \(what)") } else {
    failures += 1
    print("FAIL  \(what): got \(actual), expected \(expected)")
  }
}

expect(QuitNote.shows(dimmedInSoftware: true, isOff: false, brightness: 0.875), true,
       "a monitor Curtain dims in software, below 100%, says it goes back to full on quit")
expect(QuitNote.shows(dimmedInSoftware: true, isOff: false, brightness: 1), false,
       "at 100% nothing is dimmed, so nothing extra shows")
expect(QuitNote.shows(dimmedInSoftware: true, isOff: false, brightness: 0.996), false,
       "a value the slider shows as 100% counts as 100%")
expect(QuitNote.shows(dimmedInSoftware: true, isOff: false, brightness: 0.994), true,
       "a value the slider shows as 99% is dimmed")
expect(QuitNote.shows(dimmedInSoftware: false, isOff: false, brightness: 0.4), false,
       "an Apple or DDC screen keeps its brightness after quit: no note")
expect(QuitNote.shows(dimmedInSoftware: true, isOff: true, brightness: 0.4), false,
       "a screen that's off says it's off instead")

if failures > 0 { print("\(failures) failed"); exit(1) }
print("all passed")
