// Which brightness changes reported by macOS are news for a screen's row (#11).
//
// macOS tells Curtain about every brightness change on an Apple screen: F1/F2, Control Centre,
// auto-brightness, and Curtain's own changes too, a moment later. Its own changes are already in
// the row, and while the slider is dragged the late ones are older than what the row shows, so
// taking them would pull the slider back. A value Curtain wrote in the last second is an echo.

struct BrightnessEcho {
  /// How long after Curtain writes a value macOS may still report it back.
  static let window = 1.0
  /// Reports come back as a Float: values this close are the same value.
  static let tolerance = 0.002

  private var written: [(value: Double, at: Double)] = []

  mutating func wrote(_ value: Double, at time: Double) {
    written.removeAll { time - $0.at > Self.window }
    written.append((value, time))
  }

  func isEcho(_ value: Double, at time: Double) -> Bool {
    written.contains { time - $0.at <= Self.window && abs($0.value - value) < Self.tolerance }
  }
}
