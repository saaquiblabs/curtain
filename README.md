<h1 align="center">Curtain</h1>

**How much light each screen lets in.** Curtain sits in your menu bar and does five things:

1. **Brightness for every screen.** A slider per monitor that sets its real backlight over DDC.
   Monitors that ignore DDC are dimmed in software instead, and Curtain detects that by itself.
2. **Turn a screen off.** Two ways, both one click:
   - **Turn off** fades it to black in half a second, with no flash on your other screen.
     Windows stay where they are.
   - **Unplug** makes macOS treat it as unplugged: windows move to your other screen and the
     monitor sleeps. macOS blanks every screen for a moment while it rearranges them; Curtain
     fades through it.
   Curtain never lets you switch off your last screen, and keeps an unplugged screen unplugged
   after sleep or unlock.
3. **Brightness keys for monitors.** F1/F2 change the screen under the pointer, with the
   native macOS brightness indicator. Needs Accessibility permission.
4. **Follow the Mac.** Your monitors follow your MacBook's brightness as it changes.
5. **⌃⌥⌘C** turns off every screen except the one you're working on, or turns them all back on.

Quitting, logging out or stopping Curtain puts every screen back on. Free, open source, sends nothing anywhere. A Saaquib Labs tool. MIT.

**Needs:** macOS 13 Ventura or newer. Hardware brightness over DDC needs Apple silicon; on
Intel Macs, Curtain dims monitors in software (the curtain works on both).

## Build

No Xcode needed, just the command line tools:

```bash
make app          # builds build/Curtain.app
make run          # builds and opens it
open build/Curtain.app --args --show   # also opens the menu in a floating panel
make icon         # redraws Resources/AppIcon.icns from Tools/app-icon (only when the icon changes)
```

The first `make app` makes a self-signed "Curtain Local Signing" certificate in its own keychain
file (`~/Library/Keychains/curtain-signing.keychain-db`) and signs every build with it, so the
Accessibility permission for the brightness keys survives rebuilds. `Tools/check-signing.sh`
checks that it does.

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
