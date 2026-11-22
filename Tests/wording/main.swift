// Checks what the menu says, and what VoiceOver says for it (Sources/Wording.swift).
// `make test` builds it with that one source; touches no display.

import Foundation

var failures = 0
func expect(_ actual: String, _ expected: String, _ what: String) {
  if actual == expected { print("ok    \(what)") } else {
    failures += 1
    print("FAIL  \(what): got \"\(actual)\", expected \"\(expected)\"")
  }
}

expect(Wording.summary(off: 0, total: 2), "2 screens on", "every screen on")
expect(Wording.summary(off: 0, total: 1), "1 screen on", "one screen, singular")
expect(Wording.summary(off: 1, total: 2), "1 of 2 off", "some screens off")

expect(Wording.spokenKeys("⌃⌥C"), "Control Option C", "the shortcut's keycaps read as key names")
expect(Wording.spokenKeys("⌃⌥⌘⇧C"), "Control Option Command Shift C", "every modifier has a name")

expect(Wording.menuBarIcon(off: 0, total: 2), "Curtain, 2 screens on",
       "the menu bar icon tells VoiceOver every screen is on")
expect(Wording.menuBarIcon(off: 1, total: 2), "Curtain, 1 of 2 screens off",
       "the menu bar icon tells VoiceOver a screen is off, as its closed curtain shows")

expect(Wording.sliderLabel(screen: "L27h-4A"), "L27h-4A brightness",
       "each slider names its screen, so two sliders don't both read just Brightness")

expect(Wording.deskMap([("L27h-4A", .on), ("MacBook", .off)]), "L27h-4A on, MacBook off",
       "VoiceOver reads the desk map as one line, screen by screen (#24)")
expect(Wording.deskMap([("L27h-4A", .disconnected), ("MacBook", .on)]), "L27h-4A disconnected, MacBook on",
       "a disconnected screen is named as disconnected, not off")

if failures > 0 { print("\(failures) failed"); exit(1) }
print("all passed")
