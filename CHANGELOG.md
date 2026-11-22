# Changelog

## 0.3.1 — 2026-11-22

- **The menu fits one screen after a monitor goes, even while it was closed.** On 0.3.0, unplug
  the Lenovo with the menu closed and the next open kept the two-screen height, with bare glass
  above and below and the rows floating in the middle. The menu's SwiftUI controller was let go
  once the panel was built; its view still grew with the menu but never shrank. The panel now
  keeps it (`Sources/MenuPanel.swift`, moved out of `main.swift`) and fits itself again on every
  open. `make test` builds the real panel from made-up screens, 10,000 points off every screen,
  and checks its height against the menu's: two screens, one unplugged while open and while
  closed, plugged back in, a notice coming and going (#21). `make renders` draws the one-screen
  menu (`one-screen-light.png`, `one-screen-dark.png`).

## 0.3.0 — 2026-11-22

Curtain's own identity, Linen & Dusk, finished: frosted linen with dusk blue by day, twilight
with afterglow at night. The menu's new look (linen panel with a fine weave, raised rows, a sheer
brightness bar whose knob carries the sun, Turn off / Turn on pills, outlined switches, keycaps,
a pleated curtain across a row that's off) already went out in 0.2.2 without a line here (#4);
this release adds Curtain's own type, pointer feedback, and makes it read well to VoiceOver and
with Increase Contrast.

- **The shortcut is now ⌃⌥C** (Control+Option+C): three keys instead of four, Control and
  Option side by side under one hand, and almost no app uses it. ⌃⌥⌘C no longer does anything.
- **VoiceOver says what the menu shows**: each brightness slider names its screen ("L27h-4A
  brightness, 45 percent") instead of two sliders both saying "Brightness", the shortcut reads
  "Control Option C turns other screens off / on" instead of three symbols, the screen icons and
  the header's curtain stay quiet (the names beside them say it), and the menu bar icon says
  whether a screen is off ("Curtain, 1 of 2 screens off"), as its closed curtain shows.
  `make renders` writes what VoiceOver reaches in each state to `build/renders/*-voiceover.txt`
  and fails if a button, switch or slider loses its name.
- **Increase Contrast**: `make renders` also draws the menu with its contrast colours
  (`contrast-on`, `contrast-off`, light and dark): darker text, solid edges and outlines, a
  near-solid panel.
- **The menu fits its content and fades out**: it shrinks when a monitor's row goes, and closing
  rises and fades in 150 ms (#4).
- **Every control answers the pointer**: the pointing hand over Turn off / Turn on, the slider,
  the switches, Quit and the Accessibility link (the arrow stays over text and over a Turn off
  you can't use). Under the pointer, Turn off turns dusk blue (afterglow at night), Turn on
  glows brighter, the slider's track deepens and its knob lifts, switches deepen, Quit sits on
  a faint pill (#10).
- **Curtain's own type**: Manrope for every label, button and caption, Newsreader Italic for the
  wordmark, bundled inside the app (both OFL, credited in NOTICE) so the menu looks the same on
  every Mac. Percentages use tabular digits, so they don't jitter while you drag. If a font can't
  load, that text falls back to the system font and Curtain logs it once. The app grows by about
  0.7 MB (#5).

## 0.2.2 — 2026-11-22

- **Install with Homebrew**: `brew install saaquiblabs/tap/curtain`. It builds Curtain on your
  Mac, signs it with your Mac's own Curtain certificate and puts it in /Applications, where
  Spotlight finds it. `brew upgrade` quits Curtain, swaps it and reopens it, and the
  Accessibility permission stays; `brew uninstall` quits it first, so every screen comes back on.

- **Curtain has its own icon** in Finder, Spotlight, System Settings (Accessibility, Login
  Items): the menu's curtain, linen drapes tied back on a dusk-blue
  tile, drawn by `Tools/app-icon` (`make icon`). If an old blank icon lingers, run
  `killall Dock` or remove and re-add Curtain in Accessibility once.
- **A monitor Curtain dims in software says so while it's dimmed**: "Dimmed by Curtain until it
  quits" (its tooltip: back to full brightness on quit), so a brighter screen after quitting is no
  surprise. It shows only below 100%, and the row keeps its height at 100%; screens whose own brightness changes (MacBook, DDC monitors) keep it after quit
  and never show it. Replaces the "dimmed in software" caption, which showed even at 100%.
- **Fix: the brightness keys stopped reaching Curtain after every rebuild**, so F1/F2 changed
  the MacBook even with the pointer on a monitor, and Apple's indicator showed the MacBook's
  brightness instead of the monitor's. macOS tied the Accessibility permission to each build's
  exact hash: System Settings still showed it on, but macOS no longer trusted the new build.
  Curtain is now signed with a certificate made on your Mac, so the permission sticks. After
  updating, remove Curtain from Accessibility once and add it again.
- **The MacBook's row always shows its real brightness**, however it was changed: F1/F2,
  Control Centre, auto-brightness or Curtain. It used to keep the value it read at launch.
  Follow the Mac now reacts to the MacBook's changes as they happen instead of checking every
  second.
- If Accessibility is already on in System Settings but Curtain still can't get the keys, the
  menu says it's a permission for an older Curtain and how to renew it.
- **Fix: turning off the screen the menu was open on hid the menu behind the black.** The
  menu now moves, still open, to a screen that's on, where that screen's row reads Off with
  **Turn on** right there, and the pointer jumps to the menu. It never opens onto a screen
  that's off either.
- **Turn off is greyed out on the only screen that's on**, with a hint saying why, instead of
  explaining after the click.
- **Fix: clicking Curtain's icon while the menu was open closed it and popped it straight back
  up** (with a menu bar manager such as Ice or Bartender). The icon now opens and closes the
  menu reliably.
- **The menu closes when you move on**, like a macOS menu: a click elsewhere, switching app
  (Cmd-Tab) or Space, or focus going to another window. Just moving the pointer away keeps it
  open, so you can reach for a slider.

## 0.2.1 — 2026-11-21

- **Fix: unplugging the MacBook screen switched off its keyboard and trackpad.** macOS treats
  an unplugged built-in screen like a closed lid. The MacBook screen now only offers Turn off.
- **Fix: Unplug saved itself into macOS's display settings.** It now lasts for the session
  only, so it can't change your scaling or colour settings later. (Tested: modes and colour
  profiles identical before and after an unplug.)
- Unplug moved off the screen row: it blanks every screen for a few seconds, so it now lives
  behind a right-click on **Turn off** (monitors only), with that warning on the menu item.
- **Fix: the menu could open cut off above the top of the screen** when a menu bar manager
  (Ice, Bartender) had moved Curtain's icon. The menu is now Curtain's own panel: it opens under
  where you clicked, always fully on screen, with rounded glass corners. Esc or a click outside
  closes it.

## 0.2.0 — 2026-11-21

Switching a screen off no longer blanks every screen. Two ways to switch off, both written on
the buttons:

- **Turn off** (new, the default): the screen fades to black in about half a second. No
  rearranging, so your other screen doesn't blink. A black cover stops clicks reaching the hidden
  windows, and the backlight goes down on the MacBook (and on monitors that take DDC). Windows
  stay where they are. **Turn on** fades it back with the exact colours and brightness it had.
- **Unplug** (what 0.1 did): windows move to your other screen and the monitor sleeps. macOS
  still blanks every screen for a moment while it rearranges them, but Curtain now fades all
  screens out first and back in after, so it reads as a deliberate fade, not a glitch.
- The menu says what each click does: **Turn off**, **Unplug** and **Turn on** buttons
  instead of a curtain icon, a hint on hover, and the off screen's row says where its windows are.
- ⌃⌥⌘C now uses Turn off, so it's instant too.
- Every launch starts with all screens on. 0.1 unplugged screens again at launch if it had been
  stopped without cleaning up, which was a surprise. Being stopped by `kill` or
  `brew services stop` now also puts every screen back on.
- Brightness changes (keys, Follow the Mac) leave a turned-off screen dark.
- "MacBook screen" is now just "MacBook"; the menu is a little wider so names fit.

## 0.1.0 — 2026-11-21

The first working version: a menu bar app with the five features, built and tested on one
MacBook (M2, macOS 27.2) with one external monitor (Lenovo L27h-4A).

- **Brightness for every screen.** The MacBook screen through macOS; monitors over DDC; and
  monitors that ignore DDC are dimmed in software. Curtain spots the last case by itself: it
  reads back the first change, and if the monitor didn't take it, it switches to software and
  says so in the menu.
- **Draw the curtain.** Switch any screen off; macOS treats it as unplugged. Curtain never
  switches off your last screen, draws the curtain again when macOS turns the screen back on
  after wake or unlock, opens every curtain if nothing else is left on, and remembers curtains
  across restarts. Quit puts every screen back on.
- **Brightness keys** change the screen under the pointer, with the native brightness indicator.
- **Follow the Mac**: monitors follow the MacBook's brightness.
- **⌃⌥⌘C** draws the curtain on every screen except the one you're on, or opens them all.
- Software dimming scales each monitor's own calibrated colour curve, so colours stay true.
  (A pre-release build replaced the curve instead, which turned colours colder and bluish.)
- Built with plain `swiftc` and a Makefile, no Xcode. DDC, the brightness indicator and the
  private function declarations are ported from MonitorControl (MIT, see NOTICE).

**Known issues in 0.1**

- Drawing a curtain blanks every screen for 2–3 seconds while macOS rearranges displays.
  (0.2: Turn off avoids it; Unplug fades through it.)
- The menu doesn't yet show what a click will do before you click it. (0.2: labelled buttons.)
- The look is a first draft and borrows Lost Buttons' colours; Curtain needs its own identity.
- No app icon. Brightness keys, Follow the Mac and Open at login are untested in the real app.
- Hardware brightness over DDC needs Apple silicon; Intel Macs get software dimming.
