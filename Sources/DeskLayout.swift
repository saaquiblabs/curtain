// The desk map's layout (#24): where each screen's tile goes, from the screens' real arrangement
// (CGDisplayBounds: points, origin at the main screen's top left, y down), like System Settings →
// Displays. Pure geometry, tested in `make test` (Tests/desk-layout).

import CoreGraphics

enum DeskLayout {
  /// One frame per screen, in the map's own coordinates (top left = 0,0), in the same order. Every
  /// tile shares one scale, the largest that fits the whole desk in `maxWidth` × `maxHeight`, with
  /// neighbours `gap` apart. A screen with empty bounds (never seen connected) gets `.zero` and
  /// doesn't move the others.
  static func tiles(_ bounds: [CGRect], maxWidth: CGFloat, maxHeight: CGFloat, gap: CGFloat) -> [CGRect] {
    let known = bounds.filter { !$0.isEmpty }
    guard !known.isEmpty else { return bounds.map { _ in .zero } }
    let minX = known.map(\.minX).min()!, minY = known.map(\.minY).min()!
    // How many screens lie wholly to the left of (or above) each one: that many gaps go before it.
    func gapsBefore(_ r: CGRect) -> (x: CGFloat, y: CGFloat) {
      (CGFloat(known.filter { $0.maxX <= r.minX }.count), CGFloat(known.filter { $0.maxY <= r.minY }.count))
    }
    // Each tile's right edge is (r.maxX - minX) * scale + gaps * gap, and its bottom edge likewise:
    // every edge must stay inside the box.
    var scale = CGFloat.greatestFiniteMagnitude
    for r in known {
      let gaps = gapsBefore(r)
      let across = maxWidth - gaps.x * gap, down = maxHeight - gaps.y * gap
      if across > 0 { scale = min(scale, across / (r.maxX - minX)) }
      if down > 0 { scale = min(scale, down / (r.maxY - minY)) }
    }
    return bounds.map { r in
      guard !r.isEmpty else { return .zero }
      let gaps = gapsBefore(r)
      return CGRect(x: (r.minX - minX) * scale + gaps.x * gap, y: (r.minY - minY) * scale + gaps.y * gap,
                    width: r.width * scale, height: r.height * scale)
    }
  }

  /// The smallest size that holds every tile.
  static func size(of tiles: [CGRect]) -> CGSize {
    CGSize(width: tiles.map(\.maxX).max() ?? 0, height: tiles.map(\.maxY).max() ?? 0)
  }

  /// The screens in reading order, as indexes: left to right, then top to bottom.
  static func readingOrder(_ bounds: [CGRect]) -> [Int] {
    bounds.indices.sorted { (bounds[$0].minX, bounds[$0].minY, $0) < (bounds[$1].minX, bounds[$1].minY, $1) }
  }

  /// Where a disconnected screen's last known bounds go when the screens that stayed move (macOS
  /// moves the origin to the new main screen): along with `anchor`, a screen that stayed connected.
  static func moved(_ gone: CGRect, anchorWas: CGRect, anchorIs: CGRect) -> CGRect {
    gone.offsetBy(dx: anchorIs.minX - anchorWas.minX, dy: anchorIs.minY - anchorWas.minY)
  }
}
