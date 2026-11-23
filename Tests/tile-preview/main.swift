// Checks what a tile shows while a control is under the pointer (#26, Sources/TilePreview.swift).
// `make test` builds it with that one source; touches no display.

import Foundation

var failures = 0
func expect(_ actual: TilePreview.Look, _ expected: TilePreview.Look, _ what: String) {
  if actual == expected { print("ok    \(what)") } else {
    failures += 1
    print("FAIL  \(what): got \(actual), expected \(expected)")
  }
}

typealias Look = TilePreview.Look
let half = TilePreview.half
let on = Look(closed: 0, shown: 1, brightness: 0.45)
let off = Look(closed: 1, shown: 1, brightness: 0.45)
let gone = Look(closed: 0, shown: 0, brightness: 0.45)

func look(off: Bool = false, disconnected: Bool = false, _ preview: TilePreview.Preview?, aimed: Bool = true) -> Look {
  TilePreview.look(off: off, disconnected: disconnected, brightness: 0.45, preview: preview, aimed: aimed)
}

expect(look(nil), on, "nothing under the pointer: the tile shows the screen as it is")
expect(look(off: true, nil), off, "a screen that's off: drapes closed")
expect(look(disconnected: true, nil), gone, "a disconnected screen: only its outline")

expect(look(.turnOff), Look(closed: half, shown: 1, brightness: 0.45), "Turn off: the drapes half-close")
expect(look(off: true, .turnOn), Look(closed: half, shown: 1, brightness: 0.45), "Turn on: the drapes half-open")
expect(look(.disconnect), Look(closed: 0, shown: half, brightness: 0.45), "Disconnect: the tile half-fades")
expect(look(disconnected: true, .reconnect), Look(closed: 0, shown: half, brightness: 0.45),
       "Reconnect: the tile half-comes back")
expect(look(.brightness(0.8)), Look(closed: 0, shown: 1, brightness: 0.8), "slider: the glow follows the pointer")

expect(look(.turnOff, aimed: false), on, "another screen's Turn off leaves this tile alone")
expect(look(.brightness(0.8), aimed: false), on, "another screen's slider leaves this tile's glow alone")
expect(look(nil, aimed: true), on, "a disabled button (the only screen on) previews nothing")

expect(look(off: true, .quit, aimed: false), Look(closed: half, shown: 1, brightness: 0.45),
       "Quit: every screen that's off half-opens")
expect(look(disconnected: true, .quit, aimed: false), Look(closed: 0, shown: half, brightness: 0.45),
       "Quit: every disconnected screen half-comes back")
expect(look(.quit, aimed: false), on, "Quit: a screen that's on stays as it is")

if failures > 0 { print("\(failures) failed"); exit(1) }
print("all passed")
