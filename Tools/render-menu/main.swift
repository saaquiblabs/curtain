// Renders Curtain's real menu to PNGs from made-up screens, without touching any real display.
// Built with every app source except main.swift: `make renders` (pictures land in build/renders).
// Nothing here calls Screens.start() or Keys.start(), so no display is read, dimmed or rearranged.

import AppKit
import SwiftUI

/// One state of the menu. Built fresh for each appearance so no render inherits another's objects.
struct Fixture {
  var name: String
  var screens: () -> Screens
  var keys: () -> Keys = { Keys(preview: false) }
  /// Draw every control as if the pointer were over it (#10).
  var hover = false
  /// Draw Increase Contrast's colours (#6).
  var contrast = false
}

func macBook(_ brightness: Double = 0.72) -> Screen {
  .preview(name: "Built-in Retina Display", isBuiltin: true, control: .apple, brightness: brightness)
}

func lenovo(control: Screen.Control = .ddc, brightness: Double = 0.45, blackedOut: Bool = false, curtained: Bool = false) -> Screen {
  .preview(name: "L27h-4A", isBuiltin: false, control: control, brightness: brightness,
           blackedOut: blackedOut, curtained: curtained)
}

let fixtures: [Fixture] = [
  Fixture(name: "on", screens: { Screens(preview: [macBook(), lenovo()]) }),
  // The MacBook alone, as after the Lenovo is unplugged: the panel fits one row (#21).
  Fixture(name: "one-screen", screens: { Screens(preview: [macBook()]) }),
  Fixture(name: "software", screens: { Screens(preview: [macBook(), lenovo(control: .software, brightness: 0.4)]) }),
  Fixture(name: "software-full", screens: { Screens(preview: [macBook(), lenovo(control: .software, brightness: 1)]) }),
  Fixture(name: "off", screens: { Screens(preview: [macBook(), lenovo(blackedOut: true)]) }),
  Fixture(name: "unplugged", screens: { Screens(preview: [macBook(), lenovo(curtained: true)]) }),
  Fixture(name: "accessibility", screens: { Screens(preview: [macBook(), lenovo()]) }, keys: { Keys(preview: true) }),
  // Every control under the pointer at once: pills, slider, switches, link, Quit. In hover-off the
  // MacBook's Turn off is the only screen on, so it stays plain (disabled).
  Fixture(name: "hover", screens: { Screens(preview: [macBook(), lenovo()]) }, keys: { Keys(preview: true) }, hover: true),
  Fixture(name: "hover-off", screens: { Screens(preview: [macBook(), lenovo(blackedOut: true)]) }, hover: true),
  // Increase Contrast: stronger text, edges, outlines and a near-solid panel (#6).
  Fixture(name: "contrast-on", screens: { Screens(preview: [macBook(), lenovo(control: .software, brightness: 0.4)]) },
          keys: { Keys(preview: true) }, contrast: true),
  Fixture(name: "contrast-off", screens: { Screens(preview: [macBook(), lenovo(blackedOut: true)]) }, contrast: true),
]

let appearances: [(String, NSAppearance.Name)] = [("light", .aqua), ("dark", .darkAqua)]

/// Draws the view in an offscreen window so AppKit-backed controls (switches, links) render too,
/// which SwiftUI's ImageRenderer leaves blank. Rendered at 2x, like a Retina screen.
@MainActor
func render(_ view: some View, appearance: NSAppearance.Name, to url: URL, spoken: URL? = nil) throws {
  // The same surface as the real panel (main.swift's makePanel): Theme's glass, drawn within the window.
  let host = NSHostingView(rootView: view)
  let size = host.fittingSize
  let effect = Theme.glass(blending: .withinWindow)
  effect.frame = NSRect(origin: .zero, size: size)
  effect.addSubview(host)
  let window = NSWindow(contentRect: NSRect(x: -10_000, y: -10_000, width: size.width, height: size.height),
                        styleMask: .borderless, backing: .buffered, defer: false)
  window.appearance = NSAppearance(named: appearance)
  window.isOpaque = false
  window.backgroundColor = .clear
  window.contentView = effect
  host.frame = effect.bounds
  host.layoutSubtreeIfNeeded()
  RunLoop.main.run(until: Date().addingTimeInterval(0.15)) // let SwiftUI draw

  let scale: CGFloat = 2
  guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
  else { throw RenderError.bitmap }
  rep.size = size
  effect.cacheDisplay(in: effect.bounds, to: rep)
  guard let png = rep.representation(using: .png, properties: [:]) else { throw RenderError.png }
  try png.write(to: url)
  if spoken != nil {
    // SwiftUI builds its accessibility tree only once an assistive app asks for it; this is how
    // VoiceOver (and Electron's AXManualAccessibility) asks.
    NSApp.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: "AXManualAccessibility"))
    NSApp.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
    window.orderFrontRegardless() // still 10,000 points off every screen
    _ = host.accessibilityChildren()
    RunLoop.main.run(until: Date().addingTimeInterval(0.15))
  }
  if let spoken {
    let lines = voiceOver(host)
    try lines.joined(separator: "\n").appending("\n").write(to: spoken, atomically: true, encoding: .utf8)
    // Every control keeps a name, every slider says its percent (#6).
    let unnamed = lines.filter { $0.hasPrefix("Button: ") && $0.dropFirst(8).hasPrefix("(") || $0 == "Button: "
                                 || $0.hasPrefix("CheckBox:  =") || $0.hasPrefix("Slider:  =") }
    let silentSliders = lines.filter { $0.hasPrefix("Slider: ") && !$0.hasSuffix(" percent") }
    if !lines.contains(where: { $0.hasPrefix("Button: Quit") }) || !unnamed.isEmpty || !silentSliders.isEmpty { throw RenderError.voiceOver(unnamed + silentSliders) }
  }
  window.close()
}

/// What VoiceOver can reach in the menu, one element per line (role: label = value, then its
/// hover hint), read from the same accessibility tree VoiceOver walks. Groups that only hold
/// other elements are skipped.
@MainActor
func voiceOver(_ any: Any) -> [String] {
  guard let element = any as? NSObject else { return [] }
  // Read through the accessibility properties' Objective-C names, as an assistive app does.
  func read(_ key: String) -> String {
    guard element.responds(to: Selector(key)), let value = element.value(forKey: key) else { return "" }
    return "\(value)"
  }
  let role = read("accessibilityRole").replacingOccurrences(of: "AX", with: "")
  let name = [read("accessibilityLabel"), read("accessibilityTitle")].filter { !$0.isEmpty }.joined(separator: " / ")
  // What VoiceOver speaks for a value: its description when there is one (a slider's percent).
  let value = [read("accessibilityValueDescription"), read("accessibilityValue")].first { !$0.isEmpty } ?? ""
  let help = read("accessibilityHelp")
  let enabled = !element.responds(to: Selector(("isAccessibilityEnabled"))) || element.value(forKey: "accessibilityEnabled") as? Bool != false
  let children = element.responds(to: Selector(("accessibilityChildren"))) ? element.value(forKey: "accessibilityChildren") as? [Any] ?? [] : []
  var lines: [String] = []
  if children.isEmpty || !name.isEmpty || !value.isEmpty {
    var line = role + ": " + name
    if !value.isEmpty { line += (name.isEmpty ? "" : " = ") + value }
    if !enabled { line += " (dimmed)" }
    if !help.isEmpty { line += "\n    hint: " + help }
    lines.append(line)
  }
  return lines + children.flatMap(voiceOver)
}

enum RenderError: Error { case bitmap, png, voiceOver([String]) }

let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "build/renders", isDirectory: true)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
// The bundled fonts, as the app registers them at launch. The pictures must show the real faces,
// so a font that falls back fails the run (#5).
Fonts.register(from: URL(fileURLWithPath: "Resources/Fonts", isDirectory: true))
for role in Fonts.Role.allCases {
  guard let font = Fonts.font(role), CTFontCopyFamilyName(font) as String == role.spec.face.family else {
    print("failed: \(role) didn't resolve to \(role.spec.face.family)"); exit(1)
  }
}
print("fonts: \(Fonts.Role.allCases.count) roles in their bundled faces")
_ = NSApplication.shared
NSApp.setActivationPolicy(.prohibited)

MainActor.assumeIsolated {
  for fixture in fixtures {
    for (label, appearance) in appearances {
      let url = out.appendingPathComponent("\(fixture.name)-\(label).png")
      Theme.previewIncreaseContrast = fixture.contrast
      do {
        try render(PopoverView(screens: fixture.screens(), keys: fixture.keys()).environment(\.hoverPreview, fixture.hover),
                   appearance: appearance, to: url,
                   spoken: label == "light" && !fixture.hover && !fixture.contrast ? out.appendingPathComponent("\(fixture.name)-voiceover.txt") : nil)
        print("rendered \(url.path)")
      } catch {
        print("failed \(url.path): \(error)")
        exit(1)
      }
    }
  }
}
