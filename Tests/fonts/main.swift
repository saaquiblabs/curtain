// Checks the bundled fonts (Sources/Fonts.swift, #5): every font role resolves to its real face
// from Resources/Fonts (not a fallback), numbers get tabular digits, and a missing or broken font
// falls back to the system font, logged once. `make test` builds it with that one source and runs
// it from the repo root; touches no display.

import CoreText
import Foundation

var failures = 0
func expect(_ ok: Bool, _ what: String) {
  if ok { print("ok    \(what)") } else { failures += 1; print("FAIL  \(what)") }
}

var logged: [String] = []
Fonts.report = { logged.append($0) }

/// How wide each character of `text` is in `font`.
func advances(_ text: String, _ font: CTFont) -> [CGFloat] {
  let line = CTLineCreateWithAttributedString(
    NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]))
  return (CTLineGetGlyphRuns(line) as! [CTRun]).flatMap { run -> [CGSize] in
    var sizes = [CGSize](repeating: .zero, count: CTRunGetGlyphCount(run))
    CTRunGetAdvances(run, CFRange(location: 0, length: 0), &sizes)
    return sizes
  }.map(\.width)
}

// A broken font and a missing one, first, while nothing is registered yet.
let broken = FileManager.default.temporaryDirectory.appendingPathComponent("curtain-fonts-\(getpid())")
try FileManager.default.createDirectory(at: broken, withIntermediateDirectories: true)
try Data("not a font".utf8).write(to: broken.appendingPathComponent(Fonts.Face.manrope.file))
Fonts.register(from: broken)
expect(Fonts.loaded.isEmpty, "a broken Manrope and a missing Newsreader load nothing")
expect(Fonts.Role.allCases.allSatisfy { Fonts.font($0) == nil }, "so every role falls back to the system font")
expect(logged.count == 2, "each failure is logged (got \(logged.count): \(logged))")
Fonts.register(from: broken)
expect(logged.count == 2, "registering again logs nothing new: each failure is logged once")
try? FileManager.default.removeItem(at: broken)

// The real fonts.
let bundled = URL(fileURLWithPath: "Resources/Fonts", isDirectory: true).standardizedFileURL
Fonts.register(from: bundled)
expect(Fonts.loaded == Set(Fonts.Face.allCases), "both bundled fonts load")
for role in Fonts.Role.allCases {
  guard let font = Fonts.font(role) else { expect(false, "\(role) resolves"); continue }
  let family = CTFontCopyFamilyName(font) as String
  let url = (CTFontCopyAttribute(font, kCTFontURLAttribute) as? URL)?.standardizedFileURL
  let fromBundle = url?.deletingLastPathComponent() == bundled
  expect(family == role.spec.face.family && fromBundle,
         "\(role) is \(role.spec.face.family) from Resources/Fonts (got \(family), \(url?.path ?? "no file"))")
  let variation = CTFontCopyVariation(font) as? [NSNumber: NSNumber] ?? [:]
  // Core Text leaves out an axis that sits at the font's default (Newsreader's is 400).
  let axes = CTFontCopyVariationAxes(font) as? [[CFString: Any]] ?? []
  let wghtDefault = axes.first { ($0[kCTFontVariationAxisIdentifierKey] as? Int) == Fonts.wghtAxis }?[kCTFontVariationAxisDefaultValueKey] as? Double
  let weight = variation[NSNumber(value: Fonts.wghtAxis)]?.doubleValue ?? wghtDefault
  expect(weight == role.spec.weight, "\(role) is weight \(role.spec.weight) (got \(weight.map { "\($0)" } ?? "none"))")
  expect(CTFontGetSize(font) == role.spec.size, "\(role) is \(role.spec.size) pt")
  if role.spec.tabular {
    expect(Set(advances("0123456789", font)).count == 1, "\(role) has tabular digits: every digit is as wide")
  }
}
expect(logged.count == 2, "loading the real fonts logs nothing")

if failures > 0 { print("\(failures) failed"); exit(1) }
print("all passed")
