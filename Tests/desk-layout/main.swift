// Checks the desk map's layout: from screens' display bounds to tile frames (Sources/DeskLayout.swift,
// #24). `make test` builds it with that one source; made-up bounds only, no display touched.

import CoreGraphics
import Foundation

var failures = 0
func expect(_ ok: Bool, _ what: String, _ detail: @autoclosure () -> String = "") {
  if ok { print("ok    \(what)") } else {
    failures += 1
    print("FAIL  \(what): \(detail())")
  }
}
func near(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 0.01 }
func near(_ a: CGRect, _ b: CGRect) -> Bool {
  near(a.minX, b.minX) && near(a.minY, b.minY) && near(a.width, b.width) && near(a.height, b.height)
}

// The owner's desk (CGDisplayBounds, points): the L27h-4A on the left, the MacBook to its right,
// 198 points lower.
let lenovo = CGRect(x: 0, y: 0, width: 2560, height: 1440)
let macBook = CGRect(x: 2560, y: 198, width: 1710, height: 1112)

do {
  let tiles = DeskLayout.tiles([macBook, lenovo], maxWidth: 340, maxHeight: 90, gap: 6)
  let scale: CGFloat = 90 / 1440
  expect(near(tiles[1], CGRect(x: 0, y: 0, width: 160, height: 90)),
         "the tallest screen fills the map's 90 pt height, at its top left", "\(tiles[1])")
  expect(near(tiles[0], CGRect(x: 166, y: 198 * scale, width: 1710 * scale, height: 1112 * scale)),
         "the MacBook sits to the Lenovo's right, 6 pt apart, as low as on the desk, in the same scale", "\(tiles[0])")
  let size = DeskLayout.size(of: tiles)
  expect(near(size.width, 166 + 1710 * scale) && near(size.height, 90), "the map is as big as its tiles", "\(size)")
  expect(DeskLayout.readingOrder([macBook, lenovo]) == [1, 0], "read left to right: the Lenovo, then the MacBook")
}

do {
  // Negative coordinates: a monitor to the left of the main screen.
  let tiles = DeskLayout.tiles([CGRect(x: 0, y: 0, width: 1440, height: 900), CGRect(x: -1920, y: -180, width: 1920, height: 1080)],
                               maxWidth: 340, maxHeight: 90, gap: 6)
  expect(near(tiles[1].minX, 0) && near(tiles[1].minY, 0), "a screen left of and above the main one starts the map", "\(tiles[1])")
  expect(near(tiles[0].minX, 160 + 6) && near(tiles[0].minY, 15), "the main screen follows it", "\(tiles[0])")
}

do {
  // Three 27-inch monitors side by side don't fit at 90 pt: the map shrinks to the panel's width.
  let wide = (0..<3).map { CGRect(x: CGFloat($0) * 2560, y: 0, width: 2560, height: 1440) }
  let tiles = DeskLayout.tiles(wide, maxWidth: 340, maxHeight: 90, gap: 6)
  let size = DeskLayout.size(of: tiles)
  expect(near(size.width, 340), "a wide desk shrinks to fit the panel", "\(size)")
  expect(near(tiles[1].minX - tiles[0].maxX, 6), "the gaps stay 6 pt when it shrinks", "\(tiles)")
  expect(size.height < 90 && near(tiles[0].width / tiles[0].height, 2560 / 1440), "tiles keep their shape", "\(tiles[0])")
}

do {
  // One screen above another: a vertical gap between them, and the pair together is 90 pt high.
  let tiles = DeskLayout.tiles([CGRect(x: 0, y: 0, width: 1440, height: 900), CGRect(x: 0, y: -900, width: 1440, height: 900)],
                               maxWidth: 340, maxHeight: 90, gap: 6)
  expect(near(tiles[1].minY, 0) && near(tiles[0].minY, 42 + 6) && near(tiles[0].height, 42),
         "a screen above another sits above it, 6 pt apart", "\(tiles)")
  expect(near(DeskLayout.size(of: tiles).height, 90), "the whole map stays 90 pt high", "\(DeskLayout.size(of: tiles))")
  expect(DeskLayout.readingOrder([CGRect(x: 0, y: 0, width: 1440, height: 900), CGRect(x: 0, y: -900, width: 1440, height: 900)]) == [1, 0],
         "stacked screens read top to bottom")
}

do {
  expect(DeskLayout.tiles([], maxWidth: 340, maxHeight: 90, gap: 6).isEmpty, "no screens, no tiles")
  let tiles = DeskLayout.tiles([lenovo, .zero], maxWidth: 340, maxHeight: 90, gap: 6)
  expect(near(tiles[0], CGRect(x: 0, y: 0, width: 160, height: 90)) && tiles[1] == .zero,
         "a screen with no known bounds gets no tile and doesn't move the others", "\(tiles)")
}

do {
  // The Lenovo is disconnected; macOS makes the MacBook the origin, so every remaining screen moves
  // by the same amount. The Lenovo's last known bounds move with them, so its outline stays left of
  // the MacBook instead of landing on top of it.
  let macBookAfter = CGRect(x: 0, y: 0, width: 1710, height: 1112)
  let lenovoKept = DeskLayout.moved(lenovo, anchorWas: macBook, anchorIs: macBookAfter)
  expect(near(lenovoKept, CGRect(x: -2560, y: -198, width: 2560, height: 1440)),
         "a disconnected screen keeps its place beside the screens that stayed", "\(lenovoKept)")
  let tiles = DeskLayout.tiles([macBookAfter, lenovoKept], maxWidth: 340, maxHeight: 90, gap: 6)
  expect(near(tiles[1].minX, 0) && near(tiles[0].minX, 166), "so the map looks the same as before", "\(tiles)")
}

if failures > 0 { print("\(failures) failed"); exit(1) }
print("all passed")
