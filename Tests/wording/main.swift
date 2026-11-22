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

// One line per button under the map, saying its result (#26). Short enough for one line.
expect(Wording.turnOffLine(screen: "L27h-4A", onlyOneOn: false), "Turns L27h-4A black at once. Its windows stay on it.",
       "Turn off says the screen goes black and its windows stay")
expect(Wording.turnOffLine(screen: "MacBook", onlyOneOn: true), "MacBook is the only screen on, so it stays on.",
       "Turn off on the last screen on says why it can't")
expect(Wording.disconnectLine(screen: "L27h-4A", other: "MacBook", onlyOneOn: false),
       "Disconnects L27h-4A; windows move to MacBook, screens blink.",
       "Disconnect says where the windows go and warns of the blink (#25)")
expect(Wording.disconnectLine(screen: "L27h-4A", other: "MacBook", onlyOneOn: true),
       "L27h-4A is the only screen on, so it stays connected.",
       "Disconnect on the last screen on says why it can't")
expect(Wording.turnOnLine(screen: "L27h-4A"), "Turns L27h-4A back on, its windows as they were.",
       "Turn on says the windows are still there")
expect(Wording.reconnectLine(screen: "L27h-4A"), "Reconnects L27h-4A. Every screen blinks for a moment.",
       "Reconnect warns of the blink")
expect(Wording.brightnessLine(screen: "L27h-4A", to: 0.6), "Sets L27h-4A to 60%.",
       "the slider says the brightness under the pointer")
expect(Wording.brightnessLine(screen: "L27h-4A", to: 0.555), "Sets L27h-4A to 56%.",
       "rounded like the slider's own percent")
expect(Wording.quitLine, "Quits Curtain; every screen comes back on.", "Quit says every screen comes back on")
for line in [Wording.turnOffLine(screen: "L27h-4A", onlyOneOn: false),
             Wording.disconnectLine(screen: "L27h-4A", other: "MacBook", onlyOneOn: false),
             Wording.disconnectLine(screen: "L27h-4A", other: "MacBook", onlyOneOn: true),
             Wording.reconnectLine(screen: "L27h-4A"), Wording.quitLine] where line.count > 62 {
  failures += 1
  print("FAIL  too long for one line under the map (\(line.count) characters): \(line)")
}
expect(Wording.offLine(disconnected: true, other: "MacBook"), "Disconnected. Its windows moved to MacBook.",
       "a disconnected row says disconnected, not unplugged")

if failures > 0 { print("\(failures) failed"); exit(1) }
print("all passed")
