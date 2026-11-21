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

print(failures == 0 ? "all passed" : "\(failures) failed")
if failures > 0 { exit(1) }
