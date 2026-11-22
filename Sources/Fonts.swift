// Curtain's own typefaces (#5): Manrope for everything you read, Newsreader Italic for the
// wordmark (Linen & Dusk, issue #3). Both OFL, bundled in Contents/Resources/Fonts (see NOTICE),
// registered at launch so the menu looks the same on every Mac. Theme.Font asks here for each
// role and falls back to the system font when a face didn't load; each failure is logged once.
// Plain Core Text, no SwiftUI, so `make test` can check it on its own (Tests/fonts).

import CoreText
import Foundation
import os

enum Fonts {
  /// A bundled font file and the family Core Text reports for it.
  enum Face: CaseIterable {
    case manrope, newsreaderItalic

    var file: String {
      switch self {
      case .manrope: return "Manrope.ttf"                    // variable: weight 200–800
      case .newsreaderItalic: return "Newsreader-Italic.ttf" // variable: weight 200–800, optical size 6–72
      }
    }

    var family: String {
      switch self {
      case .manrope: return "Manrope"
      case .newsreaderItalic: return "Newsreader"
      }
    }
  }

  /// The text roles that use a bundled face. (The header's mark, row icons and keycaps stay on the
  /// system font: SF Symbols and ⌃⌥ aren't in Manrope.)
  enum Role: CaseIterable {
    case wordmark, title, body, caption, button, numeric, summary

    var spec: (face: Face, size: CGFloat, weight: Double, tabular: Bool) {
      switch self {
      case .wordmark: return (.newsreaderItalic, 18, 400, false)
      case .title: return (.manrope, 13, 600, false)
      case .body: return (.manrope, 13, 400, false)
      case .caption: return (.manrope, 10, 400, false)
      case .button: return (.manrope, 11, 600, false)
      case .numeric: return (.manrope, 11, 600, true)   // the brightness percentage: no jitter while dragging
      case .summary: return (.manrope, 10, 400, true)
      }
    }
  }

  /// The variation axes we set: weight, and Newsreader's optical size.
  static let wghtAxis = 0x7767_6874 // 'wght'
  static let opszAxis = 0x6F70_737A // 'opsz'

  /// Where a failure goes. Tests swap it to count messages.
  static var report: (String) -> Void = { message in
    Logger(subsystem: "com.saaquiblabs.curtain", category: "fonts").error("\(message, privacy: .public)")
  }

  /// The faces that loaded, each read straight from its own file.
  private static var faces: [Face: CTFontDescriptor] = [:]
  private static var reported: Set<Face> = []
  static var loaded: Set<Face> { Set(faces.keys) }

  /// Registers every bundled face found in `directory` (nil: none, e.g. a bare `build/curtain`
  /// without its app bundle). Call before the menu first draws.
  static func register(from directory: URL?) {
    faces = [:]
    for face in Face.allCases {
      guard let directory else { fail(face, "no font folder"); continue }
      let url = directory.appendingPathComponent(face.file)
      guard FileManager.default.fileExists(atPath: url.path) else { fail(face, "\(url.path) is missing"); continue }
      guard let descriptor = (CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor])?.first
      else { fail(face, "\(url.path) isn't a readable font"); continue }
      var error: Unmanaged<CFError>?
      if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
        let cfError = error?.takeRetainedValue()
        // Already registered (a second call) is fine; anything else isn't.
        if let cfError, CFErrorGetCode(cfError) != CTFontManagerError.alreadyRegistered.rawValue {
          fail(face, "\(url.path) didn't register: \(cfError)")
          continue
        }
      }
      faces[face] = descriptor
    }
  }

  /// The role's face at its size and weight (tabular digits where it counts), or nil when that
  /// face didn't load and the caller should use the system font.
  static func font(_ role: Role) -> CTFont? {
    let spec = role.spec
    guard let descriptor = faces[spec.face] else { return nil }
    var axes = [wghtAxis: spec.weight]
    if spec.face == .newsreaderItalic { axes[opszAxis] = min(max(Double(spec.size), 6), 72) }
    var attributes: [CFString: Any] = [kCTFontVariationAttribute: axes]
    if spec.tabular {
      attributes[kCTFontFeatureSettingsAttribute] = [[kCTFontOpenTypeFeatureTag: "tnum", kCTFontOpenTypeFeatureValue: 1]]
    }
    // Copying from the file's own font keeps it on our file, even if the Mac has another Manrope.
    let base = CTFontCreateWithFontDescriptor(descriptor, spec.size, nil)
    return CTFontCreateCopyWithAttributes(base, spec.size, nil, CTFontDescriptorCreateWithAttributes(attributes as CFDictionary))
  }

  private static func fail(_ face: Face, _ why: String) {
    guard reported.insert(face).inserted else { return }
    report("\(face.family) falls back to the system font: \(why)")
  }
}
