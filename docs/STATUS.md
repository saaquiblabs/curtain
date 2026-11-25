# Status — 2026-11-25

Curtain 0.5.1 is on GitHub (saaquiblabs/curtain, public, tags v0.1.0 → v0.5.1, GitHub releases from
0.5.0) and in Homebrew (`brew install saaquiblabs/tap/curtain`, cask 0.5.1), and running on the
owner's Mac (M2 MacBook Air, macOS 27.2, Lenovo L27h-4A over a USB-C/HDMI cable). Read
`CHANGELOG.md` for what each version did and `README.md` for the features.

## Handoff (2026-11-25, evening): start here
- **Shipped today:** 0.5.0 (Disconnect, hover results, Turn back on banner) and 0.5.1 (Disconnect
  and Reconnect keep the menu under Curtain's icon: owner's desk test, PR #47; tag, cask, release
  done). Curtain's page merged to `main` (#49) and deploys in ~2 min without Lighthouse (#50).
- **Open issues:** #41 (umbrella, Step 6, Curtain on the web), #42 (the page: going live, then the
  value copy), #46 (Disconnect for the MacBook's own screen; parked under #41, cap lifted once).
- **Live (2026-11-25, later):** curtain.saaquiblabs.com answers over HTTPS. Claude made the
  Openship project (`proj__6YbpR8AwDxISx8g`, D-Tox's settings) and the domain over SSH with the
  owner's permission; the first deploy ran before the domain existed, so a second deploy made the
  route. Checked from outside: `/` 200, `/privacy` 200, `/privacy/` 308 → `/privacy`, `/nope`
  404, `/changelog` shows 0.5.1. Umami (step 1) still optional. #42 was auto-closed by #49's merge
  and reopened: the value copy is still to do.
- **Next chat:** `/implement #42`: the value-proposition copy (see #42's comments): why install
  it (one screen without closing the lid or pulling a cable; darkness on demand with ⌃⌥C; monitor
  brightness from the Mac), and Turn off vs Disconnect (Turn off: windows stay, monitor backlight to
  its lowest, the Mac still draws it; Disconnect: windows move, monitor sleeps, the Mac stops
  drawing it). Numbers: only Lenovo's published ones (L27h-4A 21.7 W typical, under 0.5 W asleep,
  psref.lenovo.com) until a clean run of `Tools/measure-power.sh` (3-minute alternating steps,
  ~25 min, quiet Mac; the first 60 s run, `docs/power/pilot-*.csv`, was too noisy to publish).
  Name no other apps on the page. After #42: `/implement #46`.

## The product, as agreed with the owner
- Five features only: brightness per screen, turn a screen off, brightness keys for monitors,
  Follow the Mac, one shortcut (⌃⌥C, Control+Option+C; was ⌃⌥⌘C until 0.3.0). Nothing else unless the owner asks.
- The owner is visual: every control must show what a click will do before it's clicked
  (labelled buttons, hover hints, the screen's state written in its row). Premium, its own
  identity: Linen & Dusk (owner's pick on #3), built into the menu in #4. Every colour, font
  role, radius, surface and timing lives in `Sources/Theme.swift`; `make theme-check` fails if a
  view picks its own. Custom fonts (Newsreader Italic wordmark, Manrope everything else) are bundled in
  `Resources/Fonts` and registered at launch by `Sources/Fonts.swift` (#5; system font fallback,
  logged once; `make test` and `make renders` fail if a role misses its real face). Released as 0.3.0 (#6);
  polish after that is small 0.3.x tickets.
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
- **Disconnect** (`CGSConfigureDisplayEnabled`; called Unplug and hidden behind a right-click on
  Turn off until #25) blanks every screen 2–5 s while macOS rearranges, so it was wrapped in a 2 s
  CGDisplayFade (0.3 s out, 1.2 s hold, 0.5 s in). Since #25 (0.5.0) it's its own button on
  monitor rows (never the MacBook), Reconnect on a disconnected row; `Sources/RowButtons.swift`
  (tested) says which row gets which. In code the state is still `curtained` / `setCurtain`. **Fade test (#22, macOS 27.2, 2026-11-22):** the owner
  watched Unplug + Reconnect of the Lenovo three ways (today's 2 s fade, no fade, a short fade)
  and picked the **short fade: 0.15 s out, no hold, 0.15 s in**. `withFade` uses it since #25.
- **Never disconnect the built-in screen**: macOS treats it as a closed lid and disables the
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
- **Signed with a local self-signed certificate** (#11), not ad hoc: ad hoc's designated
  requirement is the cdhash, so every rebuild silently voided the Accessibility grant (switch
  still on, `AXIsProcessTrusted()` false, F1/F2 went to macOS). `Tools/signing-identity.sh` makes
  "Curtain Local Signing" once in `~/Library/Keychains/curtain-signing.keychain-db` (own file,
  fixed non-secret password, so `make` never prompts); requirement = identifier + certificate
  leaf. `Tools/check-signing.sh` rebuilds and fails if the requirement changes. Anyone running as
  the user can sign with it, as with any local signing setup.
- **Homebrew is a cask that builds from source** (#14): `Casks/curtain.rb` in
  saaquiblabs/homebrew-tap downloads the tagged tarball, runs `make test app` in
  `preflight_steps` and moves `Curtain.app` to /Applications. Not a formula: Spotlight doesn't
  index Homebrew's Cellar, and a formula's post-install sandbox can't write /Applications. The
  cask also quits Curtain on uninstall (`uninstall quit:`, screens restored) and on upgrade, and
  reopens it after. Not a prebuilt release zip: it would be quarantined and Gatekeeper rejects a
  self-signed, unnotarized app. The steps run in Homebrew's sandbox with `HOME` swapped for a temp
  dir, so the cask passes the real `HOME` and makes `~/Library/Keychains` writable: the user's
  "Curtain Local Signing" certificate (same file as dev builds) is made on first install and
  reused by every upgrade. **Signing outcome, verified 2026-11-22 on the owner's Mac:** a
  first-time install made the certificate inside the sandbox with no prompt; install and upgrade
  (0.2.2 → 0.2.3, local tarballs) gave the same designated requirement as `make app`; after the
  upgrade Curtain was reopened and still trusted (its event tap was live); uninstall quit it and
  left nothing running or in /Applications; Spotlight finds /Applications/Curtain.app. **Since 0.4.2
  (#37):** on macOS 26 `codesign --keychain` finds no identity unless that keychain is also on
  the user's search list (`~/Library/Preferences/com.apple.security.plist`); the script adds it,
  and the cask runs `Tools/signing-identity.sh` as its own first step with that folder writable
  (inside `make`'s sandbox the write silently does nothing). Verified on a MacBook Pro, macOS 26.6:
  brew install from a local 0.4.2 tarball with the keychain off the list. Bumping a
  version: new tag, then `version` and `sha256` in the cask, then a GitHub release for the tag
  (`gh release create vX.Y.Z --latest`, notes = brew lines + that CHANGELOG section; from 0.5.0,
  earlier tags have none). **From 0.4.1 `make app` builds
  `build/app.noindex/Curtain.app`** (Spotlight skips `.noindex` folders, so only
  /Applications/Curtain.app shows): the cask's `app` line points there from 0.4.1.
- **Apple screens' rows follow macOS's brightness reports** (#11):
  `DisplayServicesRegisterForBrightnessChangeNotifications` calls back on every change, from any
  process (verified with a second process). Curtain's own writes come back too, late; values it
  wrote in the last second are ignored (`Sources/BrightnessEcho.swift`, tested in `make test`).
  Follow the Mac rides on the same reports (and on Curtain's own MacBook changes, which are
  echoes); its 1 s timer is only a fallback. Written new: MonitorControl only reads brightness
  on demand. A DDC monitor changed with its own buttons is still read only at launch.
- **Logic tests are plain executables**: `make test` builds small executables from `Tests/<name>/main.swift` with only
  the sources they check (no XCTest with the command line tools) and runs them. First one:
  `MenuToggle`, what a click on the menu bar icon does (#7).
- **A software-dimmed screen's row says it goes back to full on quit** (#12, owner's pick of
  three): software dimming is a colour curve that ends with Curtain, so below 100% the row reads
  "Dimmed by Curtain until it quits" (line kept, invisible, at 100% so the row doesn't jump) (`Sources/QuitNote.swift`, tested in
  `make test`). No note at 100% or for Apple/DDC screens.

- **The pointing hand comes from one modifier** (#10): `.clickable()` in `Sources/UI.swift` puts
  an AppKit view behind the control with a cursor rectangle and an always-active tracking area
  (the menu is a non-activating panel, so Curtain usually isn't the active app). SwiftUI's
  `pointerStyle` needs macOS 15; push/pop leaves the hand stuck when a control vanishes under the
  pointer. Which cursor is `Sources/Pointer.swift` (tested in `make test`): hand only when
  clickable and enabled.

- **The desk map** (#24, 0.4.0, owner's pick on #23): bezelled monitors with drapes from both
  sides, above the rows, shown with two screens or more. Tiles come from `Screen.bounds`
  (`CGDisplayBounds`), laid out by `Sources/DeskLayout.swift` (whole desk fitted into 340 × 90 pt,
  6 pt gaps; tested). An unplugged screen keeps its last bounds, moved along with a screen that
  stayed when macOS shifts the origin (not yet watched on a real unplug). The rows' curtain is the
  same two-sided drapes; drapes take 720 ms, the one motion over 250 ms. Tile ↔ row lighting goes
  through `LitScreen`.
- **Hover results** (#26, 0.5.0; owner put the line under the map): `LitScreen.result`
  holds the control under the pointer (row pills, slider via `onContinuousHover`, Quit);
  `Sources/TilePreview.swift` says what its tile shows (halfway: drapes 0.5, presence 0.5, or the
  glow at the pointer's brightness; Quit reaches every tile), `HoverLine` says it under the map
  (above the row with one screen). Tooltips are gone; the lines are VoiceOver hints. A click
  clears the preview so the real change takes over with its own motion. `Drapes` animate one value
  (`Gather`, an Animatable modifier): solid until fully open, so a preview leaving takes 0.2 s and a
  real Turn on 720 ms (the old fixed 0.71 s hide made previews linger, then cut; owner's desk test).
- **Menu under the icon on Disconnect and Reconnect** (0.5.1, 2026-11-25, owner's desk test): the
  menu keeps its distance from the right edge (`MenuRefuge.fromRight`/`underIcon`), where menu bar
  icons sit on every screen, not a fraction across; it is placed again on
  `didChangeScreenParameters` (and 0.4 s later), because a returning monitor first comes back at a
  temporary place. Released: tag v0.5.1, cask 0.5.1, GitHub release.
- **MacBook Disconnect** (#46, open): the "keyboard and trackpad go off" reason was never tested;
  test it on the desk, then offer it with a safety net or correct the reason.
- **Turn back on banner** (#27, 0.5.0): `Screens.turnOff(_:)` is the one way the row's
  Turn off and ⌃⌥C turn screens off; it calls `didTurnOff`, and `TurnBackOnBanner`
  (`Sources/Banner.swift`) shows a non-activating panel at the bottom centre of the screen under
  the pointer. Where, what it names and when it goes is `Sources/TurnBackOn.swift` (tested): 6 s,
  held while the pointer is on it and 2 s after it leaves, gone at once when its screens are back
  on. Never key, so the menu stays open; its view takes the first click (`acceptsFirstMouse`).
  Esc (global + local keyDown monitors, only while it shows; global needs Accessibility) or its ×
  closes it; it can be dragged and stays where dropped (`shownOn` follows it). Owner, 2026-11-25:
  no duration setting, 6 s stays.

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
  build/app.noindex/Curtain.app --args --show` opens the menu at launch.
- Pictures of the menu: `make renders` draws the real menu from made-up screens (light and dark ×
  on, dimmed in software, dimmed in software at 100%, off, disconnected, Accessibility notice, and
  `hover`/`hover-off` with every control drawn as if under the pointer, `preview-*` with one
  control's result on the map, #26, and `banner*` for the Turn back on banner, #27) into `build/renders/`, touching no
  display (`Tools/render-menu`). The menu takes its `Screens`/`Keys` from outside; `.preview`
  initialisers build fake ones. Offscreen capture draws stray ticks on stroked capsules, so
  capsule outlines are filled rings (`CapsuleOutline`). macOS won't give an offscreen window the
  Increase Contrast appearances, so `Theme.previewIncreaseContrast` makes every colour take its
  contrast variant for the `contrast-*` renders (the real thing is still worth a look on a real
  Mac: macOS also cuts transparency then). It also writes `*-voiceover.txt`: every element
  VoiceOver reaches, read from the real accessibility tree. SwiftUI builds that tree only after
  an assistive app asks, so the tool sets `AXManualAccessibility` and `AXEnhancedUserInterface`
  on itself first (both needed); the run fails if a control loses its name or a slider its
  percent. VoiceOver wording lives in `Sources/Wording.swift` (tested in `make test`). It can't show the
  cursor either, and this terminal can't move the pointer (no Accessibility): the owner checks the
  hand cursor on their desk.
- Testing behaviour: drive `Screens.shared` from a scratch `main.swift` compiled with every source except
  `main.swift`. Test Turn off on the MacBook screen (no blink on the Lenovo the owner reads on).
  Only test Disconnect with the owner's OK: both screens go black.
- From Lost Buttons: an ad-hoc-signed app registered with SMAppService was killed at launch
  after every `brew upgrade` (cdhash pinned). Curtain is signed with a stable certificate and the
  cask keeps it at one path (/Applications/Curtain.app), so "Open at login" should survive
  upgrades; it can only be switched on from Curtain's own menu, so the owner checks it (#14).

## Not done / untested
- Brightness keys: on the owner's desk (#11) they never reached Curtain because of ad-hoc
  signing (fixed). Whether this Mac's F1/F2 arrive as system-defined events once trusted is
  still to be confirmed by the owner. Follow the Mac, Open at login: built, never exercised.
- Intel Macs: software dimming only (MonitorControl's IntelDDC not ported).
- Memory ~90 MB (SwiftUI); idle CPU not measured.
- Not on saaquiblabs.com's listing yet. Homebrew: `brew install saaquiblabs/tap/curtain` (#14).
- **Curtain's page, curtain.saaquiblabs.com (#42): live since 2026-11-25** (Openship project
  `proj__6YbpR8AwDxISx8g` and its domain made by Claude over SSH with the owner's permission;
  Umami still optional). Astro, set up like D-Tox's, pages from the owner's look on
  2026-11-25 (the app's fonts, Linen & Dusk, drapes on load, six real renders, the ⌃⌥C desk,
  `/changelog` folded as openship.io's); leads with Turn off, windows stay (owner, 2026-11-25), names no other app;
  Homebrew first, no download until notarized. Gate (`cd site && npm run verify`): Lighthouse 100
  on every page, phone and desktop; it runs in the git pre-push hook (`.githooks/pre-push`) on pushes
  touching `site/`, `CHANGELOG.md` or `README.md`. The Openship deploy runs `npm run verify:deploy`
  (tests, build, links; no Lighthouse, Install `npm ci --omit=dev`): about 2 minutes, as D-Tox's #55. Going live: the [HUMAN] steps in `site/README.md`
  (all done but Umami, which is optional). **Deploy** after each merge to `main`, by hand: `ssh najmush-oracle
  '~/.openship/bin/openship --local deploy --project proj__6YbpR8AwDxISx8g --branch main --env production
  --watch'` (domain `dom_3ahHEPds2A_XA9Dj`, certificate to 2027-02-23). After a UI change: `make renders`, then
  `cd site && npm run pictures`, commit. `/changelog` is CHANGELOG.md, so a version bump needs a
  deploy to show.

## Next (the plan agreed with the owner, one step per release)
1. ~~No more jarring blackout~~ done in 0.2.0 / 0.2.1.
2. ~~**Own identity**~~ done in 0.3.0; owner signed off on #1 (2026-11-22). Was: a page with 3 visual directions (ideas: Velvet & Brass, Linen & Dusk,
   Midnight Theatre; curtain types people buy most: sheer = dimmed, blackout = off), the real
   menu shown in each; the owner picks.
3. ~~**A menu you understand by looking**~~ done in 0.5.0 (2026-11-25, umbrella #20 closed): a map of the screens laid out like the real desk,
   each tile glowing with its brightness and a curtain sliding over it when off; verbs on every
   button; hover shows the result; "Turn back on" banner after turning off. Planned with the
   owner on 2026-11-22 as umbrella #20: panel-height fix (#21, 0.3.1), Unplug fade test (#22, done:
   owner picked a short 0.15 s + 0.15 s fade over today's 2 s one), comparison page (#23, done: owner picked bezelled monitors with drapes from both sides, the same drapes on the rows, drapes 720 ms as the one exception to the 250 ms rule; page linked on #23), desk map (#24, 0.4.0, built), Disconnect as its own
   button (#25, 0.5.0), hover results (#26, 0.5.0), Turn back on banner (#27, 0.5.0). Decisions are on #20.
   #25–#27 ship together as 0.5.0 (owner, 2026-11-22, noted on #20).
4. App icon + menu bar icon in the chosen identity (app icon done in #13).
5. Test and slim down: keys, Follow the Mac, Open at login; memory and idle CPU.
6. Release: GitHub release, Homebrew (`saaquiblabs/tap`), listing on saaquiblabs.com. Umbrella
   #41: Curtain's own page (#42, built in `site/`, going live), then the wider listing.
