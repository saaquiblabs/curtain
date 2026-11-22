// Checks where Curtain's menu goes when the screen it's open on is turned off
// (Sources/MenuRefuge.swift). `make test` builds it with that one source; touches no display.

import Foundation

var failures = 0
func expect(_ actual: UInt32?, _ expected: UInt32?, _ what: String) {
  if actual == expected { print("ok    \(what)") } else {
    failures += 1
    print("FAIL  \(what): got \(actual.map(String.init) ?? "stay"), expected \(expected.map(String.init) ?? "stay")")
  }
}

let macBook: UInt32 = 1, lenovo: UInt32 = 2, third: UInt32 = 3

expect(MenuRefuge.destination(menuOn: macBook, screensOn: [macBook, lenovo], pointerOn: macBook, menuBarOn: macBook),
       nil, "the menu stays where it is while its screen is on")

expect(MenuRefuge.destination(menuOn: macBook, screensOn: [lenovo], pointerOn: macBook, menuBarOn: macBook),
       lenovo, "turning off the MacBook with the menu on it moves the menu to the Lenovo")

expect(MenuRefuge.destination(menuOn: macBook, screensOn: [lenovo, third], pointerOn: third, menuBarOn: lenovo),
       third, "it goes to the screen the pointer is on, if that one is on")

expect(MenuRefuge.destination(menuOn: macBook, screensOn: [lenovo, third], pointerOn: macBook, menuBarOn: third),
       third, "otherwise to the screen with the main menu bar, if that one is on")

expect(MenuRefuge.destination(menuOn: macBook, screensOn: [lenovo, third], pointerOn: nil, menuBarOn: macBook),
       lenovo, "otherwise to the first screen that's on")

expect(MenuRefuge.destination(menuOn: macBook, screensOn: [], pointerOn: macBook, menuBarOn: macBook),
       nil, "with no screen on (never allowed) it stays")

expect(MenuRefuge.destination(menuOn: nil, screensOn: [lenovo], pointerOn: lenovo, menuBarOn: lenovo),
       lenovo, "a menu on no known screen goes to one that's on")

// The pointer follows the menu when the menu moved and the pointer is left on a black screen (#29).
// Owner's desk: Lenovo (menu bar) and MacBook. Whichever screen goes off, the pointer comes along.
func follows(_ actual: Bool, _ expected: Bool, _ what: String) {
  if actual == expected { print("ok    \(what)") } else { failures += 1; print("FAIL  \(what): got \(actual)") }
}
follows(MenuRefuge.pointerFollows(menuMoved: true, pointerOn: macBook, screensOn: [lenovo]), true,
        "MacBook turned off with the menu and pointer on it: the pointer follows the menu to the Lenovo")
follows(MenuRefuge.pointerFollows(menuMoved: true, pointerOn: lenovo, screensOn: [macBook]), true,
        "Lenovo turned off with the menu and pointer on it: the pointer follows the menu to the MacBook")
follows(MenuRefuge.pointerFollows(menuMoved: true, pointerOn: third, screensOn: [lenovo, third]), false,
        "the pointer already on a screen that's on stays where it is")
follows(MenuRefuge.pointerFollows(menuMoved: true, pointerOn: nil, screensOn: [lenovo]), true,
        "a pointer on no known screen follows the menu")
follows(MenuRefuge.pointerFollows(menuMoved: false, pointerOn: macBook, screensOn: [lenovo]), false,
        "the menu didn't move: the pointer is left alone")

follows(MenuRefuge.pointerFollows(menuMoved: true, pointerOn: lenovo, screensOn: [macBook], pointerOnDisconnected: true), false,
        "Lenovo disconnected with the menu and pointer on it: macOS moves the pointer, Curtain doesn't (#25)")

// Disconnect: the menu keeps its spot across the screen (#25). Owner's desk on this Mac: the
// Lenovo (main, 2560 pt wide at x 0) and the MacBook (1512 pt wide, to its right at x 2560).
func spot(_ actual: Double, _ expected: Double, _ what: String) {
  if abs(actual - expected) < 0.001 { print("ok    \(what)") } else { failures += 1; print("FAIL  \(what): got \(actual), expected \(expected)") }
}
let lenovoArea = (minX: 0.0, width: 2560.0), macBookArea = (minX: 2560.0, width: 1512.0)
spot(MenuRefuge.sameSpot(midX: 2560, from: lenovoArea, to: macBookArea), 4072, "a menu at the Lenovo's right edge lands at the MacBook's")
spot(MenuRefuge.sameSpot(midX: 640, from: lenovoArea, to: macBookArea), 2938, "a menu a quarter across the Lenovo lands a quarter across the MacBook")
spot(MenuRefuge.sameSpot(midX: 1280, from: lenovoArea, to: macBookArea), 3316, "the middle stays the middle")
spot(MenuRefuge.sameSpot(midX: -50, from: lenovoArea, to: macBookArea), 2560, "a menu past the old screen's edge lands at the new one's edge")
spot(MenuRefuge.sameSpot(midX: 100, from: (minX: 0, width: 0), to: macBookArea), 3316, "an old screen with no width: the middle of the new one")

spot(MenuRefuge.across(midX: 2560, of: lenovoArea), 1, "kept as a fraction: the right edge is 1, whatever the coordinates become")

print(failures == 0 ? "all passed" : "\(failures) failed")
if failures > 0 { exit(1) }
