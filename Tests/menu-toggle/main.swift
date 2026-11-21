// Checks what a click on Curtain's menu bar icon does (Sources/MenuToggle.swift).
// `make test` builds it with that one source and runs it; touches no display or window.

import Foundation

var failures = 0
func expect(_ actual: MenuToggle.Action, _ expected: MenuToggle.Action, _ what: String) {
  if actual == expected { print("ok    \(what)") } else { failures += 1; print("FAIL  \(what): got \(actual), expected \(expected)") }
}

do {
  var toggle = MenuToggle()
  expect(toggle.iconClicked(isOpen: false, at: 10), .open, "a click on the icon opens a closed menu")
  expect(toggle.iconClicked(isOpen: true, at: 12), .close, "a click on the icon closes an open menu")
}

do {
  // A menu bar manager draws the icon in its own bar: the click is seen as an outside click
  // first (the menu closes on its own), then reaches the icon.
  var toggle = MenuToggle()
  toggle.closedOnItsOwn(at: 20)
  expect(toggle.iconClicked(isOpen: false, at: 20.2), .ignore, "the icon click that just closed the menu doesn't reopen it")
  expect(toggle.iconClicked(isOpen: false, at: 21), .open, "the next click on the icon opens it again")
}

do {
  var toggle = MenuToggle()
  toggle.closedOnItsOwn(at: 30)
  expect(toggle.iconClicked(isOpen: false, at: 30 + MenuToggle.closingClickWindow + 0.01), .open, "a click after the closing-click window opens it")
}

do {
  // Only one click is swallowed per closing.
  var toggle = MenuToggle()
  toggle.closedOnItsOwn(at: 40)
  _ = toggle.iconClicked(isOpen: false, at: 40.1)
  expect(toggle.iconClicked(isOpen: false, at: 40.2), .open, "a second quick click opens it")
}

do {
  // However it came to be open, an open menu closes from the icon.
  var toggle = MenuToggle()
  toggle.closedOnItsOwn(at: 50)
  expect(toggle.iconClicked(isOpen: true, at: 50.1), .close, "an open menu always closes from the icon")
}

print(failures == 0 ? "all passed" : "\(failures) failed")
if failures > 0 { exit(1) }
