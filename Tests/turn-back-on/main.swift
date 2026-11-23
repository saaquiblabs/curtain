// Checks the Turn back on banner's logic (Sources/TurnBackOn.swift, #27): which screen it shows
// on, which screens it names, and when it goes. `make test` builds it with that one source and
// Sources/Wording.swift; touches no display.

import Foundation

var failures = 0
func check<T: Equatable>(_ actual: T, _ expected: T, _ what: String) {
  if actual == expected { print("ok    \(what)") } else {
    failures += 1
    print("FAIL  \(what): got \(actual), expected \(expected)")
  }
}

let macBook: UInt32 = 1, lenovo: UInt32 = 2, third: UInt32 = 3

// Where it goes: the screen you're on, if that one is on.
check(TurnBackOn.screen(pointerOn: macBook, screensOn: [macBook], menuBarOn: lenovo), macBook,
      "the Lenovo turned off from the menu on the MacBook: the banner shows on the MacBook, where the pointer is")
check(TurnBackOn.screen(pointerOn: third, screensOn: [lenovo, third], menuBarOn: lenovo), third,
      "three screens: it follows the pointer, not the menu bar")
check(TurnBackOn.screen(pointerOn: lenovo, screensOn: [macBook], menuBarOn: lenovo), macBook,
      "the pointer is on the screen that just went black: the banner goes to one that's on")
check(TurnBackOn.screen(pointerOn: macBook, screensOn: [lenovo, third], menuBarOn: third), third,
      "then the screen with the menu bar, if it's on")
check(TurnBackOn.screen(pointerOn: nil, screensOn: [lenovo, third], menuBarOn: macBook), lenovo,
      "then the first screen that's on")
check(TurnBackOn.screen(pointerOn: macBook, screensOn: [], menuBarOn: macBook), nil as UInt32?,
      "no screen on (never allowed): no banner")

// Which screens it names: the ones just turned off, plus any the banner already named that are still off.
check(TurnBackOn.named(showing: [], justOff: [lenovo], stillOff: [lenovo]), [lenovo],
      "Turn off on the Lenovo: the banner names the Lenovo")
check(TurnBackOn.named(showing: [lenovo], justOff: [third], stillOff: [lenovo, third]), [lenovo, third],
      "a second Turn off while it shows: Turn back on brings both back")
check(TurnBackOn.named(showing: [lenovo], justOff: [third], stillOff: [third]), [third],
      "a screen already back on isn't named again")
check(TurnBackOn.named(showing: [lenovo], justOff: [lenovo], stillOff: [lenovo]), [lenovo],
      "no screen is named twice")

// When it goes: 6 s after it shows, or 2 s after the pointer leaves it if that's later.
check(TurnBackOn.showing(shownAt: 100, now: 105.9, pointerLeftAt: nil, pointerOnIt: false, stillOff: 1), true,
      "it shows for about 6 s")
check(TurnBackOn.showing(shownAt: 100, now: 106, pointerLeftAt: nil, pointerOnIt: false, stillOff: 1), false,
      "and fades out on its own after 6 s")
check(TurnBackOn.showing(shownAt: 100, now: 130, pointerLeftAt: nil, pointerOnIt: true, stillOff: 1), true,
      "it stays while the pointer is on it, so it can't fade out under a click")
check(TurnBackOn.showing(shownAt: 100, now: 111.5, pointerLeftAt: 110, pointerOnIt: false, stillOff: 1), true,
      "the pointer left it after 6 s: it stays another 2 s")
check(TurnBackOn.showing(shownAt: 100, now: 112, pointerLeftAt: 110, pointerOnIt: false, stillOff: 1), false,
      "then goes")
check(TurnBackOn.showing(shownAt: 100, now: 103, pointerLeftAt: 101, pointerOnIt: false, stillOff: 1), true,
      "the pointer passing over it early doesn't cut the 6 s short")
check(TurnBackOn.showing(shownAt: 100, now: 101, pointerLeftAt: nil, pointerOnIt: true, stillOff: 0), false,
      "every screen it names is back on (from the menu or ⌃⌥C): it goes at once")
check(TurnBackOn.hidesAt(shownAt: 100, pointerLeftAt: nil), 106, "the 6 s timer ends at 106")
check(TurnBackOn.hidesAt(shownAt: 100, pointerLeftAt: 110), 112, "or 2 s after the pointer left")

// What it says.
check(Wording.bannerLine(names: ["L27h-4A"]), "L27h-4A is off", "one screen: its name")
check(Wording.bannerLine(names: ["L27h-4A", "Dell"]), "2 screens are off", "two or more: how many")
check(Wording.bannerSpoken(names: ["L27h-4A"], keys: "⌃⌥C"),
      "L27h-4A is off. Turn back on, or press Control Option C.", "what VoiceOver says")

check(Wording.bannerHint(keys: "⌃⌥C"), "Control Option C turns every screen back on too.", "the button's VoiceOver hint")

print(failures == 0 ? "all passed" : "\(failures) failed")
if failures > 0 { exit(1) }
