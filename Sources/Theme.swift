// Curtain's look: Linen & Dusk (the owner's pick on issue #3; see docs/identity/directions.html).
// Every colour, shape, surface and motion the menu uses comes from here; the views read nothing
// else. Follows macOS: frosted linen with dusk blue by day, twilight with afterglow at night.
// Increase Contrast strengthens text and edges in both.

import AppKit
import SwiftUI

enum Theme {
  // MARK: Colours

  /// Draws every colour as Increase Contrast would. Only for `make renders`: macOS won't give an
  /// offscreen window the high-contrast appearances, so the pictures can't get them otherwise.
  static var previewIncreaseContrast = false

  /// A colour that follows the appearance it's drawn in (light/dark, and Increase Contrast).
  private static func dynamic(_ light: NSColor, _ dark: NSColor,
                              contrastLight: NSColor? = nil, contrastDark: NSColor? = nil) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
      switch appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua]) {
      case .darkAqua?: return previewIncreaseContrast ? contrastDark ?? dark : dark
      case .accessibilityHighContrastAqua?: return contrastLight ?? light
      case .accessibilityHighContrastDarkAqua?: return contrastDark ?? dark
      default: return previewIncreaseContrast ? contrastLight ?? light : light
      }
    })
  }

  private static func rgb(_ hex: Int, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
  }

  // The named palette.
  private static let linen = 0xFAFAF7, duskBlue = 0x5D6FA6, duskBlueDeep = 0x4E5F93, sheer = 0xC9D3EA
  private static let twilight = 0x24293A, afterglow = 0xE8B98F, afterglowLight = 0xF0C9A6, ink = 0x2A2F3B

  /// The panel's tint over the frosted glass.
  static let panel = dynamic(rgb(linen, 0.74), rgb(twilight, 0.8),
                             contrastLight: rgb(linen, 0.97), contrastDark: rgb(twilight, 0.97))
  /// The fine weave in the panel's cloth: its horizontal and vertical threads.
  static let weaveAcross = dynamic(rgb(0x3C465A, 0.028), rgb(0xFFFFFF, 0.022))
  static let weaveDown = dynamic(rgb(0x3C465A, 0.022), rgb(0xFFFFFF, 0.016))
  /// The panel's inner edge.
  static let panelEdge = dynamic(rgb(0xFFFFFF, 0.9), rgb(0xFFFFFF, 0.1), contrastLight: rgb(ink, 0.4), contrastDark: rgb(0xFFFFFF, 0.4))

  /// Text: names and titles, secondary lines, the faintest hints.
  static let text = dynamic(rgb(ink), rgb(0xE9EAF0), contrastLight: rgb(0x14171E), contrastDark: rgb(0xFFFFFF))
  static let textSecondary = dynamic(rgb(0x687084), rgb(0xA9AEC2), contrastLight: rgb(0x3E4454), contrastDark: rgb(0xD4D7E2))
  /// A control you can't use right now (Turn off on the only screen that's on) shows at this opacity.
  static let unavailable = 0.4
  static let textFaint = dynamic(rgb(0x9AA0AE), rgb(0x767C93), contrastLight: rgb(0x555B6B), contrastDark: rgb(0xB4B9CA))
  /// The identity's mark colour: dusk blue by day, afterglow at night. The header's curtain,
  /// Turn on and switches that are on all use it.
  static let accent = dynamic(rgb(duskBlue), rgb(afterglow), contrastLight: rgb(duskBlueDeep))

  /// A screen's row.
  static let row = dynamic(rgb(0xFFFFFF, 0.66), rgb(0xFFFFFF, 0.05))
  static let rowHover = dynamic(rgb(0xFFFFFF, 0.9), rgb(0xFFFFFF, 0.08))
  static let rowEdge = dynamic(rgb(ink, 0.08), rgb(0xFFFFFF, 0.08), contrastLight: rgb(ink, 0.35), contrastDark: rgb(0xFFFFFF, 0.35))
  /// The soft disc behind a screen's icon: accent-tinted while on, plain while off.
  static let badge = dynamic(rgb(duskBlue, 0.12), rgb(afterglow, 0.14))
  static let badgeOff = dynamic(rgb(ink, 0.06), rgb(0xFFFFFF, 0.06))
  /// Rows sit on the cloth as raised cards, and lift a little under the pointer.
  static let rowShadow = Shadow(color: dynamic(rgb(0x283450, 0.10), rgb(0x000000, 0.35)), radius: 6, y: 2)
  static let rowShadowHover = Shadow(color: dynamic(rgb(0x283450, 0.16), rgb(0x000000, 0.45)), radius: 12, y: 5)

  /// Ghost pill (Turn off): a raised, thinly outlined pill, tinted under the pointer.
  static let pill = dynamic(rgb(0xFFFFFF, 0.7), rgb(0xFFFFFF, 0.04))
  static let pillText = text
  static let pillEdge = dynamic(rgb(ink, 0.16), rgb(0xFFFFFF, 0.2), contrastLight: rgb(ink, 0.6), contrastDark: rgb(0xFFFFFF, 0.6))
  /// Under the pointer the ghost pill takes on the accent: a sheer dusk (or afterglow) fill, an
  /// accent outline and accent text, so it's plain at a glance that it will respond (#10).
  static let pillHover = dynamic(rgb(0xE2E7F4), rgb(afterglow, 0.2), contrastLight: rgb(0xD5DCEE))
  static let pillEdgeHover = dynamic(rgb(duskBlue, 0.6), rgb(afterglow, 0.6), contrastLight: rgb(duskBlueDeep), contrastDark: rgb(afterglowLight))
  static let pillTextHover = dynamic(rgb(duskBlueDeep), rgb(afterglowLight), contrastLight: rgb(0x34437A))
  static let pillShadow = Shadow(color: dynamic(rgb(0x283450, 0.10), rgb(0x000000, 0.3)), radius: 2, y: 1)
  /// Solid pill (Turn on): glows in the accent colour.
  static let solidPill = accent
  static let solidPillHover = dynamic(rgb(duskBlueDeep), rgb(afterglowLight))
  static let solidPillText = dynamic(rgb(0xFFFFFF), rgb(twilight))
  static let solidPillGlow = Shadow(color: dynamic(rgb(duskBlue, 0.45), rgb(afterglow, 0.4)), radius: 6, y: 2)
  static let solidPillGlowHover = Shadow(color: dynamic(rgb(duskBlue, 0.7), rgb(afterglow, 0.65)), radius: 10, y: 3)

  /// Brightness slider: the track, the sheer fill (a gradient with a faint weave and a soft
  /// edge), the sun, and the percentage beside or on the fill.
  static let track = dynamic(rgb(ink, 0.07), rgb(0xFFFFFF, 0.07), contrastLight: rgb(ink, 0.16), contrastDark: rgb(0xFFFFFF, 0.16))
  /// Under the pointer the track deepens and the knob lifts and grows a little.
  static let trackHover = dynamic(rgb(ink, 0.12), rgb(0xFFFFFF, 0.12), contrastLight: rgb(ink, 0.24), contrastDark: rgb(0xFFFFFF, 0.24))
  static let fill = [dynamic(rgb(duskBlue, 0.32), rgb(afterglow, 0.3), contrastLight: rgb(duskBlue, 0.5)),
                     dynamic(rgb(duskBlue, 0.58), rgb(afterglow, 0.62), contrastLight: rgb(duskBlue, 0.8))]
  static let fillWeave = dynamic(rgb(0xFFFFFF, 0.18), rgb(0xFFFFFF, 0.12))
  /// Light catching the top of the fill, and its soft glow on the track.
  static let fillHighlight = [dynamic(rgb(0xFFFFFF, 0.45), rgb(0xFFFFFF, 0.22)), Color.clear]
  static let fillGlow = Shadow(color: dynamic(rgb(duskBlue, 0.30), rgb(afterglow, 0.25)), radius: 4, y: 1)
  /// The track is pressed into the row: a faint shade along its top.
  static let trackShade = [dynamic(rgb(ink, 0.07), rgb(0x000000, 0.25)), Color.clear]
  /// The sun on the slider's knob.
  static let knobMark = dynamic(rgb(duskBlue), rgb(0xC48A57), contrastLight: rgb(duskBlueDeep), contrastDark: rgb(0x8A5A30))
  static let percent = textSecondary
  static let percentOnFill = dynamic(rgb(0x2F3C66), rgb(0xFFF3E6), contrastLight: rgb(0x1C2547))

  /// Switches: outlined track, a white knob that casts a soft shadow, a glow when on.
  /// (Proportions ported from najmushsaaquib.com's prototype switch.)
  static let switchOff = dynamic(rgb(ink, 0.14), rgb(0xFFFFFF, 0.16))
  static let switchOn = accent
  /// Under the pointer: the track deepens (off) or brightens (on), the glow and knob shadow grow.
  static let switchOffHover = dynamic(rgb(ink, 0.24), rgb(0xFFFFFF, 0.26))
  static let switchOnHover = solidPillHover
  static let switchGlowHover = Shadow(color: dynamic(rgb(duskBlue, 0.6), rgb(afterglow, 0.55)), radius: 8, y: 2)
  static let switchEdge = rowEdge
  static let switchGlow = Shadow(color: dynamic(rgb(duskBlue, 0.4), rgb(afterglow, 0.35)), radius: 5, y: 1)
  static let knob = Color(nsColor: rgb(0xFFFFFF))
  static let knobShadow = Shadow(color: Color(nsColor: rgb(0x000000, 0.28)), radius: 2.5, y: 1.5)
  static let knobShadowHover = Shadow(color: Color(nsColor: rgb(0x000000, 0.4)), radius: 4, y: 2)

  /// The curtain drawn across a row that's off: pleated linen, each fold lit on one side and
  /// shaded on the other, with a shadow from its leading edge while it moves.
  static let pleatLight = dynamic(rgb(0xEEF1F8, 0.97), rgb(0x40476A, 0.96))
  static let pleatDark = dynamic(rgb(sheer, 0.97), rgb(0x232840, 0.96))
  static let gatheredOpacity = 0.0
  static let curtainShadow = Shadow(color: dynamic(rgb(0x283450, 0.25), rgb(0x000000, 0.5)), radius: 5, y: 0)

  /// The stitched thread between sections.
  static let thread = textFaint
  static let threadOpacity = 0.55

  /// Quit, under the pointer: full-strength text on a faint pill.
  static let quitHover = dynamic(rgb(ink, 0.08), rgb(0xFFFFFF, 0.1))

  /// Links (the Accessibility notice).
  static let link = dynamic(rgb(duskBlueDeep), rgb(afterglowLight), contrastLight: rgb(0x34437A))

  // MARK: Fonts by role: Manrope, with Newsreader Italic for the wordmark (Sources/Fonts.swift, #5)

  /// A role's bundled face, or the system font it falls back to if that face didn't load.
  /// Read only after Fonts.register (the app's launch, the render harness).
  private static func bundled(_ role: Fonts.Role, fallback: SwiftUI.Font) -> SwiftUI.Font {
    Fonts.font(role).map(SwiftUI.Font.init) ?? fallback
  }

  enum Font {
    static let wordmark = bundled(.wordmark, fallback: .system(size: 18, weight: .regular, design: .serif).italic())
    static let title = bundled(.title, fallback: .system(size: 13, weight: .semibold))
    static let body = bundled(.body, fallback: .system(size: 13))
    static let caption = bundled(.caption, fallback: .system(size: 10))
    static let button = bundled(.button, fallback: .system(size: 11, weight: .semibold))
    static let numeric = bundled(.numeric, fallback: .system(size: 11, weight: .semibold).monospacedDigit())
    static let summary = bundled(.summary, fallback: .system(size: 10).monospacedDigit())
    // SF Symbols and the ⌃⌥ keycaps stay on the system font: Manrope doesn't draw them.
    static let mark = SwiftUI.Font.system(size: 15, weight: .medium)
    static let icon = SwiftUI.Font.system(size: 12)
    static let keycap = SwiftUI.Font.system(size: 9.5, weight: .medium)
  }

  // MARK: Shapes

  enum Radius {
    static let panel: CGFloat = 18
    static let row: CGFloat = 14
    static let keycap: CGFloat = 4
  }

  enum Size {
    static let panelWidth: CGFloat = 372
    static let slider: CGFloat = 26
    static let badge: CGFloat = 24
    static let keycap: CGFloat = 15
    static let switchWidth: CGFloat = 38, switchHeight: CGFloat = 22, knob: CGFloat = 17, knobInset: CGFloat = 2.5
    static let gathered: CGFloat = 0        // how wide the curtain stays, gathered at the left, while the screen is on
    static let folds: [CGFloat] = [15, 19, 13, 17, 14, 20, 16] // curtain pleat widths, repeating: cloth isn't even
    static let weaveStep: CGFloat = 3       // panel weave: a 1 pt thread every 3 pt, both ways
    static let fillWeaveStep: CGFloat = 9   // slider fill: a 2 pt thread every 9 pt
    static let sliderKnobInset: CGFloat = 2.5 // the slider's knob sits this far inside the track
    static let knobHoverScale: CGFloat = 1.08 // the slider's knob grows this much under the pointer
    static let percentRoom: CGFloat = 52      // the percentage moves onto the fill when the knob gets this close to the end
    static let percentGap: CGFloat = 10
    static let sunScale: ClosedRange<CGFloat> = 0.85...1.15 // the sun grows as the screen brightens
    static let stitch: [CGFloat] = [3, 4]   // divider: 3 pt stitch, 4 pt gap
  }

  // MARK: Motion (all under 250 ms; Reduce Motion swaps movement for a short fade)

  enum Motion {
    /// The menu opens: fades in, drifting down this far.
    static let open = 0.2
    static let openDrift: CGFloat = 6
    /// ...and its content comes into focus from a soft blur and a touch smaller.
    static let openBlur: CGFloat = 4
    static let openScale: CGFloat = 0.98
    static let openContent = Animation.easeOut(duration: 0.2)
    /// The menu closes: the same in reverse, a little quicker, rising as it fades.
    static let close = 0.15
    static let closeDrift: CGFloat = 4
    static let closeContent = Animation.easeIn(duration: 0.15)
    /// Turning a screen off or on: the sheer slides across the row.
    static let veil = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.24) // fast start, long soft landing
    /// The slider glides to a click far from its edge.
    static let slider = Animation.easeOut(duration: 0.12)
    static let sliderJump = 0.08
    static let toggle = Animation.timingCurve(0.3, 0.7, 0.4, 1, duration: 0.2) // ported switch ease, kept under 250 ms
    static let press = Animation.easeOut(duration: 0.12)
    static let pressScale: CGFloat = 0.94 // pills shrink a touch while pressed (not with Reduce Motion)
    static let pressOpacity = 0.8
    static let hover = Animation.easeOut(duration: 0.12)
    static let rowHover = Animation.easeOut(duration: 0.15)
    static let swap = Animation.easeOut(duration: 0.16)
    /// With Reduce Motion: a plain fade, no movement.
    static let reduced = Animation.easeOut(duration: 0.12)
    static let reducedOpen = 0.12
    static let reducedClose = 0.1
  }

  // MARK: Depth

  /// A soft drop shadow: colour, blur and how far down it falls.
  struct Shadow {
    var color: Color
    var radius: CGFloat
    var y: CGFloat

    static let none = Shadow(color: .clear, radius: 0, y: 0)
  }

  // MARK: Surface

  /// The panel's frosted glass, rounded to the panel's corners. The linen tint, weave and edge
  /// sit on top of it in the menu itself (MenuSurface). `blending` is .behindWindow in the app,
  /// .withinWindow when rendering offscreen.
  static func glass(blending: NSVisualEffectView.BlendingMode) -> NSVisualEffectView {
    let effect = NSVisualEffectView()
    effect.material = .popover
    effect.blendingMode = blending
    effect.state = .active
    effect.wantsLayer = true
    effect.layer?.cornerRadius = Radius.panel
    effect.layer?.cornerCurve = .continuous
    effect.layer?.masksToBounds = true
    return effect
  }
}

extension View {
  /// Casts one of Theme's shadows.
  func shadow(_ shadow: Theme.Shadow) -> some View {
    self.shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
  }
}
