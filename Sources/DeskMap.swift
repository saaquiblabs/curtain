// The desk map above the rows (#24): each screen drawn as a monitor where it really sits on the
// desk, its wallpaper as bright as the screen, drapes closed over it when it's off, only a dashed
// outline left when it's unplugged, its name underneath. The owner's pick on #23: bezelled
// monitors, drapes from both sides. Hovering a tile lights up its row and the other way round;
// clicking a tile does nothing. Shown with two screens or more. Its look comes from Theme.

import SwiftUI

/// The screen whose tile or row is under the pointer, so the other one lights up too, and the
/// control under the pointer, so its tile can show what it would do (#26).
final class LitScreen: ObservableObject {
  @Published var id: CGDirectDisplayID?
  @Published var result: HoverResult?

  func hover(_ screen: CGDirectDisplayID, _ inside: Bool) {
    if inside { id = screen } else if id == screen { id = nil }
  }

  /// The pointer entered or left a control. Leaving clears only that control's result, so moving
  /// straight from one button to the next doesn't blank the next one's.
  func hover(_ control: HoverResult, _ inside: Bool) {
    if inside { result = control } else if result?.control == control.control { result = nil }
  }
}

/// What the control under the pointer would do: shown halfway on its screen's tile (every tile
/// for Quit), never on a real screen, and said in one line under the map (#26).
struct HoverResult: Equatable {
  /// Which control: its screen and its kind, so leaving it clears only its own result.
  var control: String
  /// The tile it reaches (nil: Quit, every tile).
  var screen: CGDirectDisplayID?
  /// Nil when the control is disabled: the line says why, the tile shows nothing.
  var preview: TilePreview.Preview?
  var line: String
}

struct DeskMap: View {
  @ObservedObject var screens: Screens
  @ObservedObject var lit: LitScreen

  var body: some View {
    let shown = screens.all
    let frames = DeskLayout.tiles(shown.map(\.bounds), maxWidth: Theme.Size.mapWidth,
                                  maxHeight: Theme.Size.mapHeight, gap: Theme.Size.tileGap)
    let size = DeskLayout.size(of: frames)
    ZStack(alignment: .topLeading) {
      ForEach(Array(zip(shown, frames)), id: \.0.id) { screen, frame in
        if !frame.isEmpty {
          DeskTile(screen: screen, lit: lit, size: frame.size).offset(x: frame.minX, y: frame.minY)
        }
      }
    }
    .frame(width: size.width, height: size.height + Theme.Size.mapFoot, alignment: .topLeading)
    .frame(maxWidth: .infinity)
    // One line for VoiceOver, left to right: "L27h-4A on, MacBook off". The rows keep their own.
    .accessibilityElement(children: .ignore)
    .accessibilityAddTraits(.isImage)
    .accessibilityLabel(Wording.deskMap(DeskLayout.readingOrder(shown.map(\.bounds)).map { index in
      let screen = shown[index]
      return (screen.name, screen.curtained ? .disconnected : screen.blackedOut ? .off : .on)
    }))
  }
}

/// One screen on the map.
private struct DeskTile: View {
  @ObservedObject var screen: Screen
  @ObservedObject var lit: LitScreen
  var size: CGSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    let gone = screen.curtained, off = screen.blackedOut, isLit = lit.id == screen.id
    let laptop = screen.isBuiltin
    let result = lit.result
    let look = TilePreview.look(off: off, disconnected: gone, brightness: screen.brightness,
                                preview: result?.preview, aimed: result?.screen == screen.id)
    let shape = laptop ? Corners(top: Theme.Radius.laptopTop, bottom: Theme.Radius.laptopBottom)
                       : Corners(top: Theme.Radius.monitor, bottom: Theme.Radius.monitor)
    ZStack {
      ZStack {
        shape.fill(Theme.bezel)
        shape.strokeBorder(Theme.bezelEdge, lineWidth: 1)
        glass(look: look, off: off)
          .padding(.horizontal, Theme.Size.bezel)
          .padding(.top, Theme.Size.bezel)
          .padding(.bottom, laptop ? Theme.Size.laptopChin : Theme.Size.bezel)
      }
      .shadow(Theme.tileGlow(off ? 0 : look.brightness))
      .opacity(look.shown)
      shape.strokeBorder(Theme.tileOutline, style: StrokeStyle(lineWidth: Theme.Size.outlineWidth, dash: Theme.Size.outlineDash))
        .opacity(1 - look.shown)
      shape.inset(by: -Theme.Size.ringGap).strokeBorder(Theme.tileRing, lineWidth: Theme.Size.ringWidth)
        .opacity(isLit ? 1 : 0)
    }
    .frame(width: size.width, height: size.height)
    .overlay(alignment: .top) { base(laptop: laptop).offset(y: size.height).opacity(look.shown) }
    .overlay(alignment: .top) {
      Text(screen.name)
        .font(Theme.Font.caption)
        .foregroundStyle(gone ? Theme.tileNameGone : isLit ? Theme.tileNameLit : Theme.tileName)
        .lineLimit(1)
        .frame(width: size.width + Theme.Size.tileGap)
        .offset(y: size.height + (laptop ? Theme.Size.nameBelowLaptop : Theme.Size.nameBelowMonitor))
    }
    .contentShape(Rectangle())
    .onHover { lit.hover(screen.id, $0) }
    .animation(Theme.Motion.rowHover, value: isLit)
    // A preview comes and goes quickly; a real change (the screen turned off, disconnected)
    // keeps its own motion, which wins when both happen at once (a click ends the preview).
    .animation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.preview, value: result)
    .animation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.tileGone, value: gone)
  }

  /// The glass: a dusk wallpaper, light along its top, darkened as the screen dims, and the drapes.
  private func glass(look: TilePreview.Look, off: Bool) -> some View {
    ZStack(alignment: .top) {
      LinearGradient(colors: Theme.wallpaper, startPoint: Theme.wallpaperStart, endPoint: Theme.wallpaperEnd)
      Theme.screenSheen.frame(height: Theme.Size.sheen)
      Theme.screenDim.opacity((1 - look.brightness) * Theme.screenDimMax)
      Drapes(closed: look.closed, real: off, reduceMotion: reduceMotion, folds: Theme.Size.tileFolds,
             shadow: Theme.tileCurtainShadow)
    }
    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.glass, style: .continuous))
  }

  /// What the screen stands on: a monitor's stand, or the MacBook's keyboard deck.
  @ViewBuilder private func base(laptop: Bool) -> some View {
    if laptop {
      Corners(top: 0, bottom: Theme.Radius.deck).fill(Theme.deck)
        .frame(width: size.width * (1 + 2 * Theme.Size.deckOverhang), height: Theme.Size.deckHeight)
        .overlay(alignment: .top) {
          Corners(top: 0, bottom: Theme.Size.deckNotch).fill(Theme.deckNotch)
            .frame(width: size.width * Theme.Size.deckNotchWidth, height: Theme.Size.deckNotch)
        }
    } else {
      VStack(spacing: 0) {
        Rectangle().fill(Theme.deck)
          .frame(width: Theme.Size.standNeck, height: Theme.Size.standHeight - Theme.Size.standFoot)
        Capsule().fill(Theme.deck).frame(width: Theme.Size.standWidth, height: Theme.Size.standFoot)
      }
    }
  }
}

/// A rectangle with one radius for its top corners and another for its bottom ones (a MacBook's
/// lid). UnevenRoundedRectangle needs macOS 14.
struct Corners: InsettableShape {
  var top: CGFloat
  var bottom: CGFloat
  var inset: CGFloat = 0

  func path(in rect: CGRect) -> Path {
    let r = rect.insetBy(dx: inset, dy: inset)
    let t = max(0, min(top - inset, r.width / 2, r.height / 2)), b = max(0, min(bottom - inset, r.width / 2, r.height / 2))
    var path = Path()
    path.move(to: CGPoint(x: r.minX + t, y: r.minY))
    path.addLine(to: CGPoint(x: r.maxX - t, y: r.minY))
    path.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.minY + t), radius: t)
    path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - b))
    path.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.maxX - b, y: r.maxY), radius: b)
    path.addLine(to: CGPoint(x: r.minX + b, y: r.maxY))
    path.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.maxY - b), radius: b)
    path.addLine(to: CGPoint(x: r.minX, y: r.minY + t))
    path.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.minX + t, y: r.minY), radius: t)
    path.closeSubpath()
    return path
  }

  func inset(by amount: CGFloat) -> Corners { Corners(top: top, bottom: bottom, inset: inset + amount) }
}

/// The drapes across a screen that's off, on its row and its tile: two pleated panels that close
/// from the edges and meet in the middle, their folds opening as they go, and gather back when the
/// screen comes on (a fade with Reduce Motion). Each is one flattened layer so it moves smoothly.
/// On a tile they can stop halfway, previewing Turn off or Turn on (#26).
struct Drapes: View {
  /// How far closed: 0 open, 1 closed, half while a button's result is previewed.
  var closed: Double
  /// Whether the screen is really off. Turning it off or on takes the drapes' own 720 ms; a
  /// preview coming or going takes the tile's quicker motion.
  var real: Bool
  var reduceMotion: Bool
  /// How wide the pleats are, against a row's.
  var folds: CGFloat = 1
  var shadow: Theme.Shadow = Theme.curtainShadow

  var body: some View {
    GeometryReader { geo in
      let half = geo.size.width * Theme.Size.drapeOverlap
      ZStack {
        drape(half: half, from: .leading, shadow: shadow)
        drape(half: half, from: .trailing, shadow: shadow.mirrored)
      }
      .frame(width: geo.size.width, height: geo.size.height)
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private func drape(half: CGFloat, from edge: HorizontalAlignment, shadow: Theme.Shadow) -> some View {
    let anchor: UnitPoint = edge == .leading ? .leading : .trailing
    let drawn = closed > 0
    return Pleats(folds: folds, alignment: edge == .leading ? .leading : .trailing)
      .drawingGroup()
      .frame(width: half)
      .scaleEffect(x: reduceMotion ? 1 : max(Theme.Size.gathered, closed), anchor: anchor)
      .shadow(shadow)
      .animation(Theme.Motion.drapes, value: real)
      // Solid while it moves: it shows as it starts to close, and goes once it has opened. With
      // Reduce Motion it doesn't move, it fades (halfway for a preview).
      .opacity(reduceMotion ? closed : drawn ? 1 : 0)
      .animation(reduceMotion ? Theme.Motion.reduced : drawn ? Theme.Motion.drapesShow : Theme.Motion.drapesHide, value: drawn)
      .frame(maxWidth: .infinity, alignment: edge == .leading ? .leading : .trailing)
  }

  /// Folds side by side, each lit on its left and shaded on its right, gathered at the drape's edge.
  private struct Pleats: View {
    var folds: CGFloat
    var alignment: Alignment

    var body: some View {
      GeometryReader { geo in
        let widths = Theme.Size.folds.map { $0 * folds }
        HStack(spacing: 0) {
          ForEach(0..<Int((geo.size.width / widths.min()!).rounded(.up)), id: \.self) { index in
            Rectangle()
              .fill(LinearGradient(colors: [Theme.pleatDark, Theme.pleatLight, Theme.pleatLight, Theme.pleatDark],
                                   startPoint: .leading, endPoint: .trailing))
              .frame(width: widths[index % widths.count])
          }
        }
        .frame(width: geo.size.width, height: geo.size.height, alignment: alignment)
        .clipped()
      }
    }
  }
}
