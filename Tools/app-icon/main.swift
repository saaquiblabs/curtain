// Draws Curtain's app icon: the menu header's curtain on a dusk-blue tile, in Linen & Dusk (see
// Sources/Theme.swift). The owner picked this one ("C · The mark on dusk") on issue #13.
//
// Usage: app-icon <out.iconset>   writes every PNG macOS asks for; `make icon` then runs
// iconutil to make Resources/AppIcon.icns.
//
// Our own curtain, not the menu's SF Symbol: Apple's licence keeps SF Symbols out of app icons.
// Drawn on Apple's macOS icon grid: an 824 pt continuous-corner square centred on a 1024 pt
// canvas, with a soft shadow under it. Below 64 px the pleats are left out and the rod and
// tie-backs get thicker, so the shape still reads at 16 px.

import AppKit
import SwiftUI

// The Linen & Dusk palette (same values as Theme.swift).
func rgb(_ hex: Int, _ alpha: CGFloat = 1) -> CGColor {
  CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
          blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}
let linen = rgb(0xFAFAF7), sheer = rgb(0xC9D3EA), duskBlueDeep = rgb(0x4E5F93)
let tileTop = rgb(0x6E80B8) // dusk blue (0x5D6FA6), lifted a little so the tile has light from above
let folds: [CGFloat] = [15, 19, 13, 17, 14, 20, 16] // the menu's pleat widths, repeating: cloth isn't even

/// The tile: Apple's grid square with continuous corners (22.5% radius), as SwiftUI draws it.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = RoundedRectangle(cornerRadius: tile.width * 0.225, style: .continuous).path(in: tile).cgPath

/// How far down the drapes are tied back, and how close they come at the rod.
let tieAt: CGFloat = 0.58
let gap: CGFloat = 230

/// One drape as a closed path, in top-left coordinates. Its inner edge runs from the rod, out to
/// the tie-back at the side, and flares a little to the hem. `left` false mirrors it.
func drape(left: Bool, in area: CGRect) -> CGPath {
  let outer = left ? area.minX : area.maxX
  let s: CGFloat = left ? 1 : -1 // +1 heads inwards for the left drape
  let top = area.minY, bottom = area.maxY
  let innerTop = area.midX - s * gap / 2
  let waistY = top + area.height * tieAt
  let waistX = outer + s * area.width * 0.15
  let hemX = outer + s * area.width * 0.24
  let path = CGMutablePath()
  path.move(to: CGPoint(x: outer, y: top))
  path.addLine(to: CGPoint(x: innerTop, y: top))
  path.addCurve(to: CGPoint(x: waistX, y: waistY),
                control1: CGPoint(x: innerTop, y: top + (waistY - top) * 0.45),
                control2: CGPoint(x: waistX + s * 40, y: waistY - 70))
  path.addCurve(to: CGPoint(x: hemX, y: bottom),
                control1: CGPoint(x: waistX + s * 10, y: waistY + 50),
                control2: CGPoint(x: hemX - s * 4, y: bottom - 60))
  path.addLine(to: CGPoint(x: outer, y: bottom))
  path.closeSubpath()
  return path
}

func linear(_ colors: [CGColor]) -> CGGradient {
  CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)!
}

/// Draws the icon on a context set up as 1024×1024 units, top-left origin; `scale` is pixels per unit.
func draw(in ctx: CGContext, scale: CGFloat) {
  let detailed = scale * 1024 >= 64
  // Shadows ignore the context's transform: scale them by hand, and flip y so they fall down.
  func shadow(y: CGFloat, blur: CGFloat, _ color: CGColor) {
    ctx.setShadow(offset: CGSize(width: 0, height: -y * scale), blur: blur * scale, color: color)
  }

  // The tile and its shadow.
  ctx.saveGState()
  shadow(y: 10, blur: 20, rgb(0x000000, 0.3))
  ctx.addPath(tilePath); ctx.setFillColor(duskBlueDeep); ctx.fillPath()
  ctx.restoreGState()
  ctx.saveGState()
  ctx.addPath(tilePath); ctx.clip()
  ctx.drawLinearGradient(linear([tileTop, duskBlueDeep]), start: CGPoint(x: 0, y: tile.minY),
                         end: CGPoint(x: 0, y: tile.maxY), options: [])

  // Where the curtain hangs, with the rod across the top.
  let area = tile.insetBy(dx: detailed ? 150 : 130, dy: detailed ? 170 : 150).offsetBy(dx: 0, dy: 20)
  let rodHeight: CGFloat = detailed ? 30 : 48
  let rod = CGRect(x: area.minX - 40, y: area.minY - rodHeight, width: area.width + 80, height: rodHeight)

  for left in [true, false] {
    let path = drape(left: left, in: area)
    ctx.saveGState()
    shadow(y: 6, blur: 14, rgb(0x000000, 0.22))
    ctx.addPath(path); ctx.setFillColor(linen); ctx.fillPath()
    ctx.restoreGState()
    guard detailed else { continue }
    // Folds side by side, lit in the middle and shaded at the edges (the menu's pleats).
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    let pleat = linear([sheer, linen, linen, sheer])
    var x = area.minX
    var index = left ? 0 : 3
    while x < area.maxX {
      let w = folds[index % folds.count] * 3.2
      ctx.saveGState()
      ctx.clip(to: CGRect(x: x, y: area.minY, width: w, height: area.height))
      ctx.drawLinearGradient(pleat, start: CGPoint(x: x, y: 0), end: CGPoint(x: x + w, y: 0), options: [])
      ctx.restoreGState()
      x += w; index += 1
    }
    ctx.restoreGState()
  }

  ctx.setFillColor(linen)
  // The tie-backs: a band around each drape at its waist.
  let band: CGFloat = detailed ? 22 : 40
  let bandWidth = area.width * (detailed ? 0.17 : 0.2)
  for x in [area.minX - 8, area.maxX - bandWidth + 8] {
    ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: area.minY + area.height * tieAt - band / 2, width: bandWidth, height: band),
                       cornerWidth: band / 2, cornerHeight: band / 2, transform: nil))
  }
  // The rod, with a round finial at each end.
  ctx.addPath(CGPath(roundedRect: rod, cornerWidth: rodHeight / 2, cornerHeight: rodHeight / 2, transform: nil))
  let finial = rodHeight * 1.5
  for cx in [rod.minX, rod.maxX] {
    ctx.addEllipse(in: CGRect(x: cx - finial / 2, y: rod.midY - finial / 2, width: finial, height: finial))
  }
  ctx.fillPath()
  ctx.restoreGState()
}

func png(px: Int) -> Data {
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
  let scale = CGFloat(px) / 1024
  ctx.translateBy(x: 0, y: CGFloat(px)); ctx.scaleBy(x: scale, y: -scale) // top-left origin, 1024 units
  draw(in: ctx, scale: scale)
  return rep.representation(using: .png, properties: [:])!
}

guard CommandLine.arguments.count == 2 else {
  FileHandle.standardError.write("usage: app-icon <out.iconset>\n".data(using: .utf8)!)
  exit(2)
}
let out = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
// The names iconutil expects: each point size at 1x and 2x.
for points in [16, 32, 128, 256, 512] {
  try png(px: points).write(to: out.appendingPathComponent("icon_\(points)x\(points).png"))
  try png(px: points * 2).write(to: out.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
