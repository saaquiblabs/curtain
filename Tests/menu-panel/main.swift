// Checks the real menu panel fits its content when a monitor goes, open or closed (#21).
// `make test` builds it with every app source except main.swift. Made-up screens only: nothing
// calls Screens.start(), so no display is read, dimmed or rearranged. The panel sits 10,000
// points off every screen.

import AppKit
import SwiftUI

var failures = 0
func expect(_ ok: Bool, _ what: String, _ detail: @autoclosure () -> String = "") {
  if ok { print("ok    \(what)") } else {
    failures += 1
    print("FAIL  \(what): \(detail())")
  }
}

func macBook() -> Screen { .preview(name: "Built-in Retina Display", isBuiltin: true, control: .apple, brightness: 0.72) }
func lenovo() -> Screen { .preview(name: "L27h-4A", isBuiltin: false, control: .ddc, brightness: 0.45) }

/// Lets SwiftUI and AppKit lay out and report sizes.
func settle() { RunLoop.main.run(until: Date().addingTimeInterval(0.3)) }

/// The menu's own height for these screens, drawn on its own.
@MainActor
func contentHeight(_ screens: [Screen]) -> CGFloat {
  NSHostingView(rootView: PopoverView(screens: Screens(preview: screens), keys: Keys(preview: false))).fittingSize.height
}

_ = NSApplication.shared
NSApp.setActivationPolicy(.prohibited)

MainActor.assumeIsolated {
  let one = contentHeight([macBook()]), two = contentHeight([macBook(), lenovo()])
  expect(two > one + 20, "a second screen makes the menu taller", "one \(one), two \(two)")

  let screens = Screens(preview: [macBook(), lenovo()])
  let presence = MenuPresence()
  let panel = MenuPanel.make(showing: PopoverView(screens: screens, keys: Keys(preview: false), presence: presence),
                             presence: presence)
  func height() -> CGFloat { panel.contentLayoutRect.height }
  func open() { panel.setFrameTopLeftPoint(NSPoint(x: -10_000, y: -10_000)); panel.orderFrontRegardless(); settle() }
  func close() { panel.orderOut(nil); settle() }

  open()
  expect(abs(height() - two) < 1, "two screens: the panel is as tall as the menu", "panel \(height()), menu \(two)")

  // The Lenovo goes while the menu is open: SwiftUI reports the change and the panel shrinks (#4).
  screens.replacePreview(with: [macBook()]); settle()
  expect(abs(height() - one) < 1, "monitor unplugged while open: the panel shrinks", "panel \(height()), menu \(one)")
  screens.replacePreview(with: [macBook(), lenovo()]); settle()
  expect(abs(height() - two) < 1, "monitor plugged in while open: the panel grows", "panel \(height()), menu \(two)")

  // The Lenovo goes while the menu is closed, then the menu opens: the owner's case on 0.3.0,
  // where the panel kept its two-screen height (#21). Checked before any fit().
  close()
  screens.replacePreview(with: [macBook()]); settle()
  expect(abs(height() - one) < 1, "monitor unplugged while closed: the panel shrinks before opening", "panel \(height()), menu \(one)")
  open()
  expect(abs(height() - one) < 1, "…and opens fitted", "panel \(height()), menu \(one)")
  panel.fit() // what the app does on every open
  expect(abs(height() - one) < 1, "…and fit() on open leaves it fitted", "panel \(height()), menu \(one)")

  close()
  screens.replacePreview(with: [macBook(), lenovo()]); settle()
  open()
  expect(abs(height() - two) < 1, "monitor plugged in while closed: the panel opens fitted", "panel \(height()), menu \(two)")

  // A notice under the rows (a screen that can't be dimmed) comes and goes while closed.
  close()
  screens.notice = "L27h-4A can't be dimmed over its cable."; settle()
  let withNotice = height()
  screens.notice = nil; settle()
  open()
  expect(withNotice > two + 10 && abs(height() - two) < 1, "a notice grows the panel and its going shrinks it, while closed",
         "with notice \(withNotice), after \(height()), menu \(two)")
}

if failures > 0 { print("\(failures) failed"); exit(1) }
print("all passed")
