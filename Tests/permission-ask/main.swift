// Checks how Curtain asks for Accessibility (Sources/PermissionAsk.swift): one window per click.
// `make test` builds it with that one source; touches no setting.

import Foundation

var failures = 0
func expect(_ actual: PermissionAsk, _ expected: PermissionAsk, _ what: String) {
  if actual == expected { print("ok    \(what)") } else {
    failures += 1
    print("FAIL  \(what): got \(actual), expected \(expected)")
  }
}

expect(PermissionAsk.next(askedBefore: false), .systemPrompt,
       "the first click shows only macOS's own Accessibility dialog (it lists Curtain and opens Settings)")
expect(PermissionAsk.next(askedBefore: true), .openSettings,
       "later clicks open only System Settings at Accessibility: macOS shows its dialog just once")

print(failures == 0 ? "all passed" : "\(failures) failed")
if failures > 0 { exit(1) }
