// Checks which brightness changes macOS reports a screen's row should take
// (Sources/BrightnessEcho.swift). `make test` builds it with that one source; touches no display.

import Foundation

var failures = 0
func expect(_ actual: Bool, _ expected: Bool, _ what: String) {
  if actual == expected { print("ok    \(what)") } else {
    failures += 1
    print("FAIL  \(what): got \(actual), expected \(expected)")
  }
}

var echo = BrightnessEcho()
expect(echo.isEcho(0.6, at: 10), false, "a change Curtain didn't make (F1/F2, Control Centre) is taken")

echo.wrote(0.5, at: 20)
expect(echo.isEcho(0.5, at: 20.1), true, "Curtain's own change coming back is not news")

echo.wrote(0.40, at: 30); echo.wrote(0.45, at: 30.05); echo.wrote(0.50, at: 30.1)
expect(echo.isEcho(0.40, at: 30.2), true, "while the slider is dragged, an older value arriving late doesn't pull it back")
expect(echo.isEcho(0.45, at: 30.2), true, "nor the next one")

echo.wrote(0.7, at: 40)
expect(echo.isEcho(0.7, at: 45), false, "long after Curtain wrote it, the same value is a real change")

echo.wrote(0.3, at: 50)
expect(echo.isEcho(0.8, at: 50.1), false, "a different value right after Curtain's change is a real change")

echo.wrote(0.25, at: 60)
expect(echo.isEcho(Double(Float(0.25)), at: 60.1), true, "macOS reports a Float: the rounding is still Curtain's value")

if failures > 0 { print("\(failures) failed"); exit(1) }
print("all passed")
