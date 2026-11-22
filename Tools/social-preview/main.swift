// Draws the 1280x640 picture GitHub shows when the repo is linked (#15): the icon, the name and
// one line on the left, the menu by day and by night on the right, on a twilight background.
// `make screenshots` runs it after the renders. GitHub has no API for this picture: upload
// docs/img/social-preview.png in the repo's Settings > General > Social preview.
// Usage: social-preview <icon.png> <screenshots dir> <out.png>

import AppKit

let args = CommandLine.arguments
guard args.count == 4 else { print("usage: social-preview <icon.png> <screenshots dir> <out.png>"); exit(2) }

func rgb(_ hex: Int, _ alpha: CGFloat = 1) -> NSColor {
  NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
          blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}
// Linen & Dusk, as in Sources/Theme.swift.
let twilight = rgb(0x24293A), twilightDeep = rgb(0x1A1E2B), linen = rgb(0xFAFAF7), afterglow = rgb(0xE8B98F)

func image(_ path: String) -> NSImage {
  guard let image = NSImage(contentsOfFile: path) else { print("can't read \(path)"); exit(1) }
  return image
}
let icon = image(args[1])
let day = image(args[2] + "/on-light.png"), night = image(args[2] + "/off-dark.png")

let size = NSSize(width: 1280, height: 640)
guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
else { exit(1) }
rep.size = size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

NSGradient(starting: twilight, ending: twilightDeep)!.draw(in: NSRect(origin: .zero, size: size), angle: -90)

/// Draws a menu picture (rendered at 2x) at `scale` of its point size, with a soft shadow.
func drawMenu(_ menu: NSImage, at origin: NSPoint, scale: CGFloat) {
  let rect = NSRect(origin: origin, size: NSSize(width: menu.size.width * scale, height: menu.size.height * scale))
  NSGraphicsContext.saveGraphicsState()
  let shadow = NSShadow()
  shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
  shadow.shadowBlurRadius = 30
  shadow.shadowOffset = NSSize(width: 0, height: -10)
  shadow.set()
  menu.draw(in: rect)
  NSGraphicsContext.restoreGraphicsState()
}
// The menu pictures are 372x423 points; day behind, night in front and lower.
drawMenu(day, at: NSPoint(x: 640, y: 150), scale: 1.0)
drawMenu(night, at: NSPoint(x: 860, y: 40), scale: 1.0)

icon.draw(in: NSRect(x: 72, y: 340, width: 180, height: 180))

func text(_ string: String, _ font: NSFont, _ color: NSColor, at point: NSPoint) {
  NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color]).draw(at: point)
}
let serif = NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body).withDesign(.serif)!
  .withSymbolicTraits(.italic)
let wordmark = NSFont(descriptor: serif, size: 84) ?? NSFont.systemFont(ofSize: 84)
text("Curtain", wordmark, linen, at: NSPoint(x: 84, y: 228))
text("How much light each screen lets in.", .systemFont(ofSize: 26, weight: .medium), linen.withAlphaComponent(0.85),
     at: NSPoint(x: 88, y: 186))
text("Brightness for every monitor, and a curtain", .systemFont(ofSize: 21), rgb(0xA9AEC2), at: NSPoint(x: 88, y: 132))
text("to switch any of them off. macOS menu bar.", .systemFont(ofSize: 21), rgb(0xA9AEC2), at: NSPoint(x: 88, y: 104))
text("brew install saaquiblabs/tap/curtain", .monospacedSystemFont(ofSize: 18, weight: .medium), afterglow,
     at: NSPoint(x: 88, y: 52))

NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
do { try png.write(to: URL(fileURLWithPath: args[3])) } catch { print("can't write \(args[3]): \(error)"); exit(1) }
print("drew \(args[3])")
