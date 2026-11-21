<h1 align="center">Curtain</h1>

**How much light each screen lets in.** Curtain sits in your menu bar and does five things:

1. **Brightness for every screen.** A slider per monitor that sets its real backlight over DDC.
   Monitors that ignore DDC are dimmed in software instead, and Curtain detects that by itself.
2. **Draw the curtain.** Switch any screen off in one click. macOS treats it as unplugged:
   windows move to your other screen and the monitor goes to sleep. Click again to bring it back.
   Curtain never lets you switch off your last screen, and draws the curtain again when macOS
   turns the screen back on after sleep or unlock.
3. **Brightness keys for monitors.** F1/F2 change the screen under the pointer, with the
   native macOS brightness indicator. Needs Accessibility permission.
4. **Follow the Mac.** Your monitors follow your MacBook's brightness as it changes.
5. **⌃⌥⌘C** draws the curtain on every screen except the one you're working on, or opens it.

Quit puts every screen back on. Free, open source, sends nothing anywhere. A Saaquib Labs tool. MIT.

**Needs:** macOS 13 Ventura or newer. Hardware brightness over DDC needs Apple silicon; on
Intel Macs, Curtain dims monitors in software (the curtain works on both).

## Build

No Xcode needed, just the command line tools:

```bash
make app          # builds build/Curtain.app
make run          # builds and opens it
open build/Curtain.app --args --show   # also opens the menu in a floating panel
```

## How the curtain works

Curtain calls `CGSConfigureDisplayEnabled`, an undocumented macOS function that tells
macOS to treat a display as unplugged. Apps like BetterDisplay and Lunar sell the same
feature as part of a paid plan. Because the function is undocumented, Curtain looks it up when
it starts: if a future macOS removes it, the curtain button stops working and the rest of the
app keeps going.

## Credits

The DDC code (`Sources/DDC.swift`), the brightness indicator (`Sources/OSD.swift`) and the
private function declarations (`Sources/Private.swift`) are ported from
[MonitorControl](https://github.com/MonitorControl/MonitorControl) (MIT). Their licence is in
[NOTICE](NOTICE). Thank you to its authors.
