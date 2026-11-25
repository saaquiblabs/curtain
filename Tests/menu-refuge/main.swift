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

// Disconnect and Reconnect: the pointer keeps its spot on the menu (#25). Menu 360 x 500 pt.
func at(_ actual: CGPoint, _ expected: CGPoint, _ what: String) {
  if abs(actual.x - expected.x) < 0.001, abs(actual.y - expected.y) < 0.001 { print("ok    \(what)") } else {
    failures += 1; print("FAIL  \(what): got \(actual), expected \(expected)")
  }
}
let macBookFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
at(MenuRefuge.pointer(offset: CGPoint(x: 300, y: 120), menu: CGRect(x: 1000, y: 450, width: 360, height: 500), screen: macBookFrame),
   CGPoint(x: 1300, y: 830), "the pointer on the Disconnect button stays on that row of the menu on the MacBook")
at(MenuRefuge.pointer(offset: CGPoint(x: 300, y: 120), menu: CGRect(x: 1400, y: 450, width: 360, height: 500), screen: macBookFrame),
   CGPoint(x: 1511, y: 830), "a spot that would fall off the screen stays on its edge")
at(MenuRefuge.pointer(offset: CGPoint(x: 300, y: 120), menu: CGRect(x: 2000, y: 900, width: 360, height: 500),
                      screen: CGRect(x: 0, y: 0, width: 2560, height: 1440)),
   CGPoint(x: 2300, y: 1280), "Reconnect: back on the Lenovo, the same spot on the menu")

// Disconnect: the menu stays under Curtain's icon (#25; owner, 2026-11-25). Owner's desk on this
// Mac: the Lenovo (main, 2560 pt wide at x 0) and the MacBook (1470 pt wide, to its right at x
// 2560). The icon sits the same distance from the right edge on both.
func spot(_ actual: Double, _ expected: Double, _ what: String) {
  if abs(actual - expected) < 0.001 { print("ok    \(what)") } else { failures += 1; print("FAIL  \(what): got \(actual), expected \(expected)") }
}
let lenovoArea = (minX: 0.0, width: 2560.0), macBookArea = (minX: 2560.0, width: 1470.0)
// The menu opened under the icon, 300 pt from the Lenovo's right edge (its middle at 2260).
let fromRight = MenuRefuge.fromRight(midX: 2260, of: lenovoArea)
spot(fromRight, 300, "the menu under the icon: 300 pt from the Lenovo's right edge")
spot(MenuRefuge.underIcon(fromRight: fromRight, on: macBookArea), 3730, "Disconnect: 300 pt from the MacBook's right edge, under its icon, not at the far right")
spot(MenuRefuge.underIcon(fromRight: fromRight, on: lenovoArea), 2260, "Reconnect: back under the Lenovo's icon, not in the middle")
// macOS moves every screen's coordinates when the main screen goes; the distance doesn't care.
spot(MenuRefuge.underIcon(fromRight: fromRight, on: (minX: 0, width: 1470)), 1170, "the MacBook as main at x 0: still 300 pt from its right edge")
spot(MenuRefuge.underIcon(fromRight: 2000, on: macBookArea), 2560, "further from the edge than the new screen is wide: kept on it, at its left edge")
spot(MenuRefuge.fromRight(midX: 2700, of: lenovoArea), 0, "a middle past the right edge counts as at the edge")
spot(MenuRefuge.fromRight(midX: -50, of: lenovoArea), 2560, "a middle past the left edge counts as the whole width")

print(failures == 0 ? "all passed" : "\(failures) failed")
if failures > 0 { exit(1) }
