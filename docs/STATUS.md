# Status — 2026-11-21

Curtain 0.2.1 is on GitHub (saaquiblabs/curtain, public, tags v0.1.0 → v0.2.1) and running on
the owner's Mac (M2 MacBook Air, macOS 27.2, Lenovo L27h-4A over a USB-C/HDMI cable). Read
`CHANGELOG.md` for what each version did and `README.md` for the five features.

## The product, as agreed with the owner
- Five features only: brightness per screen, turn a screen off, brightness keys for monitors,
  Follow the Mac, one shortcut (⌃⌥⌘C). Nothing else unless the owner asks.
- The owner is visual: every control must show what a click will do before it's clicked
  (labelled buttons, hover hints, the screen's state written in its row). Premium, its own
  identity: Linen & Dusk (owner's pick on #3), built into the menu in #4. Every colour, font
  role, radius, surface and timing lives in `Sources/Theme.swift`; `make theme-check` fails if a
  view picks its own. Custom fonts (Newsreader, Manrope) come in #5; release 0.3.0 in #6.
- Small steps, one release each, each with a CHANGELOG entry.

## Decisions made (candidates for ADRs)
- **Port, don't fork.** MonitorControl needs Xcode (storyboards, SPM); this Mac has only the
  command line tools. Ported DDC (`Sources/DDC.swift`), the brightness indicator
  (`Sources/OSD.swift`) and private declarations (`Sources/Private.swift`), MIT, in `NOTICE`.
  Built with `swiftc` + Makefile like Lost Buttons. No SwiftUI `@State` (the CLT lack its macro
  plugin): use ButtonStyles / ObservableObjects instead.
- **Turn off is the default** way to switch a screen off: gamma fades to 0 in ~0.25 s, a black
  window at shielding level blocks clicks, backlight to 0 (Apple screens / DDC). No display
  rearrangement, so no blink. The pointer can still wander onto it (invisible).
- **Unplug** (`CGSConfigureDisplayEnabled`) blanks every screen 2–5 s while macOS rearranges;
  unavoidable. Wrapped in a CGDisplayFade, behind a right-click on Turn off, monitors only.
- **Never unplug the built-in screen**: macOS treats it as a closed lid and disables the
  built-in keyboard and trackpad (happened to the owner).
- **Session-only display changes** (`.forSession`). `.permanently` rewrote macOS's saved display
  arrangement. macOS still touches its display plist on any change, but modes and profiles stay.
- **Every launch starts with all screens on.** Any exit (Quit, logout, SIGTERM/INT/HUP) restores
  screens, backlights and colours.
- **Software dimming scales the screen's own calibrated gamma table** (captured before Curtain
  touches it). Writing a plain formula curve turned the Lenovo blue.
- **Apple display = built-in or vendor 1552.** macOS 27's DisplayServices "accepts" brightness
  for any monitor but the hardware never changes.
- **DDC is verified once**: the first real change is read back; if ignored, that monitor is
  dimmed in software from then on (`ddcIgnored.<uuid>` default).
- **The menu never sits on a screen that's off** (#8, owner's pick): Turn off's cover is above
  the menu, so `place()` moves it, still open, to a screen that's on (pointer's, then the main
  menu bar's, then any; `Sources/MenuRefuge.swift`, tested in `make test`).
- **The menu is Curtain's own panel** (borderless NSPanel, glass, under the click), not
  NSPopover, which placed itself off-screen when a menu bar manager moved the icon.
- **Logic tests are plain executables**: `make test` builds small executables from `Tests/<name>/main.swift` with only
  the sources they check (no XCTest with the command line tools) and runs them. First one:
  `MenuToggle`, what a click on the menu bar icon does (#7).

## Learned the hard way (keep)
- The owner's Lenovo answers DDC reads but ignores every write (brightness, contrast); likely
  the HDMI↔USB-C cable. Owner hasn't checked the monitor's DDC/CI menu yet. A USB-C↔USB-C
  (DisplayPort) cable would probably make hardware brightness work.
- macOS sends a reconfiguration callback when a display goes off but not when it comes back,
  so Curtain also re-checks on wake, screens wake, session active, unlock and screen-parameter
  changes.
- Colour profiles were set to the panels' own factory profiles on 2026-11-21 (Lenovo
  "L27h-4A", MacBook "Color LCD"); they had been Display P3 / Adobe RGB overrides.
- The owner's menu bar is full: a menu bar manager hides Curtain's icon. `open
  build/Curtain.app --args --show` opens the menu at launch.
- Pictures of the menu: `make renders` draws the real menu from made-up screens (light and dark ×
  on, dimmed in software, off, unplugged, Accessibility notice) into `build/renders/`, touching no
  display (`Tools/render-menu`). The menu takes its `Screens`/`Keys` from outside; `.preview`
  initialisers build fake ones. Offscreen capture draws stray ticks on stroked capsules, so
  capsule outlines are filled rings (`CapsuleOutline`). It can't draw Increase Contrast (macOS
  won't give an offscreen window those appearances): check that on a real Mac.
- Testing behaviour: drive `Screens.shared` from a scratch `main.swift` compiled with every source except
  `main.swift`. Test Turn off on the MacBook screen (no blink on the Lenovo the owner reads on).
  Only test Unplug with the owner's OK: both screens go black.
- From Lost Buttons: an ad-hoc-signed app registered with SMAppService was killed at launch
  after every `brew upgrade` (cdhash pinned). Curtain's "Open at login" uses SMAppService, so
  expect the same once it ships via Homebrew; untested.

## Not done / untested
- Brightness keys (needs Accessibility for Curtain.app), Follow the Mac, Open at login: built,
  never exercised in the real app.
- No app icon. Intel Macs: software dimming only (MonitorControl's IntelDDC not ported).
- Memory ~90 MB (SwiftUI); idle CPU not measured.
- No GitHub release page, no Homebrew formula, not on saaquiblabs.com yet.

## Next (the plan agreed with the owner, one step per release)
1. ~~No more jarring blackout~~ done in 0.2.0 / 0.2.1.
2. **Own identity**: a page with 3 visual directions (ideas: Velvet & Brass, Linen & Dusk,
   Midnight Theatre; curtain types people buy most: sheer = dimmed, blackout = off), the real
   menu shown in each; the owner picks.
3. **A menu you understand by looking**: a map of the screens laid out like the real desk,
   each tile glowing with its brightness and a curtain sliding over it when off; verbs on every
   button; hover shows the result; "Turn back on" banner after turning off.
4. App icon + menu bar icon in the chosen identity.
5. Test and slim down: keys, Follow the Mac, Open at login; memory and idle CPU.
6. Release: GitHub release, Homebrew (`saaquiblabs/tap`), listing on saaquiblabs.com.
