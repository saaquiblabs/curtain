// Whether a screen's row says Curtain's dimming ends when Curtain quits (#12).
//
// A monitor that ignores brightness commands is dimmed in software: Curtain scales its colour
// curve. That only lasts while Curtain runs; on quit the curve goes back and the screen returns
// to full. So while such a screen is below 100% its row says so. Apple and DDC screens change
// the hardware, which keeps its brightness after quit.

enum QuitNote {
  /// `brightness` is the slider's value (0...1); one the slider shows as 100% counts as 100%.
  static func shows(dimmedInSoftware: Bool, isOff: Bool, brightness: Double) -> Bool {
    dimmedInSoftware && !isOff && (brightness * 100).rounded() < 100
  }
}
