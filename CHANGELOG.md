# Changelog

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
- The menu doesn't yet show what a click will do before you click it.
- The look is a first draft and borrows Lost Buttons' colours; Curtain needs its own identity.
- No app icon. Brightness keys, Follow the Mac and Open at login are untested in the real app.
- Hardware brightness over DDC needs Apple silicon; Intel Macs get software dimming.
