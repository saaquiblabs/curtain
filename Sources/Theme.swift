// Curtain's look: Linen & Dusk (the owner's pick on issue #3; see docs/identity/directions.html).
// Every colour, shape, surface and motion the menu uses comes from here; the views read nothing
// else. Follows macOS: frosted linen with dusk blue by day, twilight with afterglow at night.
// Increase Contrast strengthens text and edges in both.

import AppKit
import SwiftUI

enum Theme {
  // MARK: Colours

  /// A colour that follows the appearance it's drawn in (light/dark, and Increase Contrast).
  private static func dynamic(_ light: NSColor, _ dark: NSColor,
                              contrastLight: NSColor? = nil, contrastDark: NSColor? = nil) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
      switch appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua]) {
      case .darkAqua?: return dark
      case .accessibilityHighContrastAqua?: return contrastLight ?? light
      case .accessibilityHighContrastDarkAqua?: return contrastDark ?? dark
      default: return light
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
  static let panel = dynamic(rgb(linen, 0.86), rgb(twilight, 0.88),
                             contrastLight: rgb(linen, 0.97), contrastDark: rgb(twilight, 0.97))
  /// The fine weave in the panel's cloth: its horizontal and vertical threads.
  static let weaveAcross = dynamic(rgb(0x3C465A, 0.028), rgb(0xFFFFFF, 0.022))
  static let weaveDown = dynamic(rgb(0x3C465A, 0.022), rgb(0xFFFFFF, 0.016))
  /// The panel's inner edge.
  static let panelEdge = dynamic(rgb(0xFFFFFF, 0.9), rgb(0xFFFFFF, 0.1), contrastLight: rgb(ink, 0.4), contrastDark: rgb(0xFFFFFF, 0.4))

  /// Text: names and titles, secondary lines, the faintest hints.
  static let text = dynamic(rgb(ink), rgb(0xE9EAF0), contrastLight: rgb(0x14171E), contrastDark: rgb(0xFFFFFF))
  static let textSecondary = dynamic(rgb(0x687084), rgb(0xA9AEC2), contrastLight: rgb(0x3E4454), contrastDark: rgb(0xD4D7E2))
  static let textFaint = dynamic(rgb(0x9AA0AE), rgb(0x767C93), contrastLight: rgb(0x555B6B), contrastDark: rgb(0xB4B9CA))
  /// The identity's mark colour: dusk blue by day, afterglow at night. The header's curtain,
  /// Turn on and switches that are on all use it.
  static let accent = dynamic(rgb(duskBlue), rgb(afterglow), contrastLight: rgb(duskBlueDeep))

  /// A screen's row.
  static let row = dynamic(rgb(0xFFFFFF, 0.66), rgb(0xFFFFFF, 0.05))
  static let rowHover = dynamic(rgb(0xFFFFFF, 0.9), rgb(0xFFFFFF, 0.08))
  static let rowEdge = dynamic(rgb(ink, 0.08), rgb(0xFFFFFF, 0.08), contrastLight: rgb(ink, 0.35), contrastDark: rgb(0xFFFFFF, 0.35))

  /// Ghost pill (Turn off): no fill, an outline, filled faintly on hover.
  static let pill = Color.clear
  static let pillText = text
  static let pillEdge = dynamic(rgb(ink, 0.18), rgb(0xFFFFFF, 0.2), contrastLight: rgb(ink, 0.6), contrastDark: rgb(0xFFFFFF, 0.6))
  static let pillHover = dynamic(rgb(duskBlue, 0.1), rgb(afterglow, 0.12))
  /// Solid pill (Turn on).
  static let solidPill = accent
  static let solidPillHover = dynamic(rgb(duskBlueDeep), rgb(afterglowLight))
  static let solidPillText = dynamic(rgb(0xFFFFFF), rgb(twilight))

  /// Brightness slider: the track, the sheer fill (a gradient with a faint weave and a soft
  /// edge), the sun, and the percentage beside or on the fill.
  static let track = dynamic(rgb(ink, 0.07), rgb(0xFFFFFF, 0.07), contrastLight: rgb(ink, 0.16), contrastDark: rgb(0xFFFFFF, 0.16))
  static let fill = [dynamic(rgb(duskBlue, 0.32), rgb(afterglow, 0.3), contrastLight: rgb(duskBlue, 0.5)),
                     dynamic(rgb(duskBlue, 0.58), rgb(afterglow, 0.62), contrastLight: rgb(duskBlue, 0.8))]
  static let fillWeave = dynamic(rgb(0xFFFFFF, 0.18), rgb(0xFFFFFF, 0.12))
  static let fillEdge = Color(nsColor: rgb(0xFFFFFF, 0.55))
  static let fillMark = dynamic(rgb(0x3E4D7E), rgb(0xFBE3CB), contrastLight: rgb(0x26315A))
  static let percent = textSecondary
  static let percentOnFill = dynamic(rgb(0x2F3C66), rgb(0xFFF3E6), contrastLight: rgb(0x1C2547))

  /// Switches: outlined track, white knob.
  static let switchOff = dynamic(rgb(ink, 0.12), rgb(0xFFFFFF, 0.14))
  static let switchOn = accent
  static let switchEdge = rowEdge
  static let knob = Color(nsColor: rgb(0xFFFFFF))
  static let knobShadow = Color(nsColor: rgb(0x000000, 0.3))
  static let knobShadowHover = Color(nsColor: rgb(0x000000, 0.45))

  /// The sheer drawn across a row that's off: a fading gradient with a few threads.
  static let veil = [dynamic(rgb(sheer, 0.75), rgb(0x141826, 0.7)),
                     dynamic(rgb(sheer, 0.35), rgb(0x141826, 0.3))]
  static let veilThread = Color(nsColor: rgb(0xFFFFFF, 0.18))

  /// The stitched thread between sections.
  static let thread = textFaint
  static let threadOpacity = 0.55

  /// Links (the Accessibility notice).
  static let link = dynamic(rgb(duskBlueDeep), rgb(afterglowLight), contrastLight: rgb(0x34437A))

  // MARK: Fonts by role (system font for now; the bundled faces come in #5)

  enum Font {
    static let wordmark = SwiftUI.Font.system(size: 18, weight: .regular, design: .serif).italic()
    static let mark = SwiftUI.Font.system(size: 15, weight: .medium)
    static let title = SwiftUI.Font.system(size: 13, weight: .medium)
    static let body = SwiftUI.Font.system(size: 13)
    static let caption = SwiftUI.Font.system(size: 10)
    static let button = SwiftUI.Font.system(size: 11, weight: .semibold)
    static let numeric = SwiftUI.Font.system(size: 11, weight: .semibold).monospacedDigit()
    static let summary = SwiftUI.Font.system(size: 10).monospacedDigit()
    static let icon = SwiftUI.Font.system(size: 13)
  }

  // MARK: Shapes

  enum Radius {
    static let panel: CGFloat = 18
    static let row: CGFloat = 14
  }

  enum Size {
    static let panelWidth: CGFloat = 372
    static let slider: CGFloat = 26
    static let switchWidth: CGFloat = 26, switchHeight: CGFloat = 15, knob: CGFloat = 11
    static let weaveStep: CGFloat = 3       // panel weave: a 1 pt thread every 3 pt, both ways
    static let fillWeaveStep: CGFloat = 9   // slider fill: a 2 pt thread every 9 pt
    static let veilThreadStep: CGFloat = 11 // veil: a 1 pt thread every 11 pt
    static let knobShadow: CGFloat = 1, knobShadowHover: CGFloat = 2
    static let percentOnFillAbove = 0.85      // the percentage sits on the fill above this
    static let stitch: [CGFloat] = [3, 4]   // divider: 3 pt stitch, 4 pt gap
  }

  // MARK: Motion (all under 250 ms; Reduce Motion swaps movement for a short fade)

  enum Motion {
    /// The menu opens: fades in, drifting down this far.
    static let open = 0.2
    static let openDrift: CGFloat = 6
    /// Turning a screen off or on: the sheer slides across the row.
    static let veil = Animation.timingCurve(0.3, 0.7, 0.2, 1, duration: 0.22)
    /// The slider glides to a click far from its edge.
    static let slider = Animation.easeOut(duration: 0.12)
    static let sliderJump = 0.08
    static let toggle = Animation.timingCurve(0.3, 0.7, 0.2, 1, duration: 0.16)
    static let press = Animation.easeOut(duration: 0.12)
    static let pressScale: CGFloat = 0.94 // pills shrink a touch while pressed (not with Reduce Motion)
    static let pressOpacity = 0.8
    static let hover = Animation.easeOut(duration: 0.12)
    static let rowHover = Animation.easeOut(duration: 0.15)
    static let swap = Animation.easeOut(duration: 0.16)
    /// With Reduce Motion: a plain fade, no movement.
    static let reduced = Animation.easeOut(duration: 0.12)
    static let reducedOpen = 0.12
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
