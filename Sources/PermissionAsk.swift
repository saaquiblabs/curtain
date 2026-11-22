// How Curtain asks for Accessibility (#29). Plain logic, tested in `make test`.
//
// macOS shows its own "Curtain would like to control this computer" dialog only the first time an
// app asks; that dialog lists Curtain and has its own button to System Settings. Curtain used to
// show that dialog and open System Settings at the same moment: two windows on the first click,
// then only Settings after. Now each click opens exactly one.

enum PermissionAsk: Equatable {
  case systemPrompt, openSettings

  static func next(askedBefore: Bool) -> PermissionAsk {
    askedBefore ? .openSettings : .systemPrompt
  }
}
