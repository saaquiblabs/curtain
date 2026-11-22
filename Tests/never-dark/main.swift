// Checks Curtain never leaves every screen dark (#29): the pure rule (Sources/NeverDark.swift),
// then the owner's case on made-up screens. `make test` builds it with every app source except
// main.swift. Nothing calls Screens.start(), so no display is read, dimmed or rearranged.

import AppKit

var failures = 0
func expect(_ ok: Bool, _ what: String) {
  if ok { print("ok    \(what)") } else { failures += 1; print("FAIL  \(what)") }
}

// The rule: given each remaining screen's off state, must everything come back on?
expect(!NeverDark.mustTurnAllOn(screensOff: [false, true]), "one screen still visible: nothing changes")
expect(NeverDark.mustTurnAllOn(screensOff: [true]), "the only screen left is turned off: everything comes back on")
expect(NeverDark.mustTurnAllOn(screensOff: [true, true]), "an unplugged and a turned-off screen, nothing visible: everything comes back on")
expect(!NeverDark.mustTurnAllOn(screensOff: [false]), "the only screen left is on: nothing changes")
expect(!NeverDark.mustTurnAllOn(screensOff: []), "no screen at all: nothing to turn on")

func macBook(off: Bool = false) -> Screen {
  .preview(name: "MacBook", isBuiltin: true, control: .apple, brightness: 0.7, blackedOut: off)
}
func lenovo(off: Bool = false, unplugged: Bool = false) -> Screen {
  .preview(name: "L27h-4A", isBuiltin: false, control: .software, brightness: 0.5, blackedOut: off, curtained: unplugged)
}

// Owner's case: pointer on the Lenovo, Turn off the MacBook, then the Lenovo's cable comes out.
do {
  let mac = macBook(off: true)
  let screens = Screens(preview: [mac, lenovo()])
  expect(mac.blackedOut, "the MacBook is turned off while the Lenovo is on")
  screens.replacePreview(with: [mac])
  expect(!mac.blackedOut && !mac.isOff, "Lenovo unplugged: the MacBook is back on")
}

// The same with the Lenovo unplugged by Curtain and the MacBook turned off: nothing visible.
do {
  let mac = macBook(off: true), len = lenovo(unplugged: true)
  let screens = Screens(preview: [mac, lenovo()])
  screens.replacePreview(with: [mac, len])
  expect(!mac.isOff && !len.isOff, "an unplugged and a turned-off screen left: both come back on")
}

// Lid closed: the MacBook goes, only the turned-off Lenovo is left.
do {
  let len = lenovo(off: true)
  let screens = Screens(preview: [macBook(), len])
  screens.replacePreview(with: [len])
  expect(!len.isOff, "lid closed with the Lenovo turned off: the Lenovo comes back on")
}

// A screen still visible: the turned-off one stays off.
do {
  let mac = macBook(off: true), len = lenovo()
  let screens = Screens(preview: [mac, len, lenovo()])
  screens.replacePreview(with: [mac, len])
  expect(mac.blackedOut, "another screen still on: the turned-off MacBook stays off")
}

print(failures == 0 ? "all passed" : "\(failures) failed")
if failures > 0 { exit(1) }
