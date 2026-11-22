PREFIX ?= /usr/local
SWIFTC ?= swiftc
FLAGS = -O -swift-version 5 -target $(shell uname -m)-apple-macos13.0
VERSION := $(shell sed -n 's/^let version = "\(.*\)"/\1/p' Sources/main.swift)
APP = build/Curtain.app
BUNDLE_ID = com.saaquiblabs.curtain

build/curtain: Sources/*.swift
	@mkdir -p build
	$(SWIFTC) $(FLAGS) Sources/*.swift -o $@

# The app bundle: same binary, plus the name and icon macOS shows in the menu bar, Login Items
# and the Accessibility list.
app: build/curtain Resources/Info.plist Resources/AppIcon.icns Resources/Fonts/*.ttf
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources/Fonts"
	cp build/curtain "$(APP)/Contents/MacOS/curtain"
	sed 's/@VERSION@/$(VERSION)/g' Resources/Info.plist > "$(APP)/Contents/Info.plist"
	cp Resources/AppIcon.icns "$(APP)/Contents/Resources/AppIcon.icns"
	cp Resources/Fonts/*.ttf Resources/Fonts/OFL-*.txt "$(APP)/Contents/Resources/Fonts/" # Manrope, Newsreader Italic and their licences (NOTICE)
	$(MAKE) sign

# Redraws Resources/AppIcon.icns from Tools/app-icon (only needed when the icon changes; the .icns
# is checked in). Same iconset-to-iconutil steps as ../lost-buttons.
icon:
	@mkdir -p build
	$(SWIFTC) $(FLAGS) Tools/app-icon/main.swift -o build/app-icon
	rm -rf build/AppIcon.iconset
	build/app-icon build/AppIcon.iconset
	iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
	@mkdir -p docs/img
	cp build/AppIcon.iconset/icon_256x256.png docs/img/curtain-256.png

# Signed with this Mac's own Curtain certificate (Tools/signing-identity.sh makes it the first
# time; no Apple account needed), so the Accessibility permission survives rebuilds (#11). Ad hoc
# signing tied it to each build's hash: after a rebuild System Settings still showed it on, but
# macOS no longer trusted the app and the brightness keys went to macOS.
sign:
	keychain=$$(Tools/signing-identity.sh) && codesign --force --keychain "$$keychain" \
	  --sign "Curtain Local Signing" --identifier $(BUNDLE_ID) "$(APP)"

# Waits for the old Curtain to finish quitting (it restores every screen first): opening it while
# it's still on its way out fails with LaunchServices error -600.
run: app
	-pkill -x curtain
	@for i in $$(seq 50); do pgrep -x curtain >/dev/null || break; sleep 0.1; done
	open "$(APP)"

.PHONY: app icon sign run install uninstall clean renders screenshots theme-check test
install: app
	rm -rf "$(PREFIX)/Curtain.app"
	cp -R "$(APP)" "$(PREFIX)/Curtain.app"

uninstall:
	rm -rf "$(PREFIX)/Curtain.app"

clean:
	rm -rf build

# Pictures of the real menu drawn from made-up screens (see Tools/render-menu). Touches no display.
renders: theme-check
	@mkdir -p build
	$(SWIFTC) $(FLAGS) $(filter-out Sources/main.swift,$(wildcard Sources/*.swift)) Tools/render-menu/main.swift -o build/render-menu
	build/render-menu build/renders

# The README's pictures (#15): three of the renders, light and dark, copied where GitHub can show
# them, plus the 1280x640 social preview (uploaded by hand in the repo's Settings).
screenshots: renders
	@mkdir -p docs/screenshots
	for look in light dark; do \
	  cp build/renders/on-$$look.png docs/screenshots/on-$$look.png; \
	  cp build/renders/software-$$look.png docs/screenshots/dimmed-$$look.png; \
	  cp build/renders/off-$$look.png docs/screenshots/off-$$look.png; \
	done
	$(SWIFTC) $(FLAGS) Tools/social-preview/main.swift -o build/social-preview
	build/social-preview docs/img/curtain-256.png docs/screenshots docs/img/social-preview.png

# The menu's look lives only in Sources/Theme.swift: fail if a view picks its own colour, font,
# corner radius or timing.
theme-check:
	@! grep -nE 'Color[.(]|\.(secondary|tertiary|quaternary|primary|white|black)\b|duration:|\.font\(\.|\.system\(|cornerRadius: [0-9]|\.tint\(' Sources/UI.swift Sources/main.swift \
	  || { echo "theme-check: visual values above belong in Sources/Theme.swift"; exit 1; }

# Logic tests: plain executables built with only the sources they check. Touch no display.
test:
	@mkdir -p build
	$(SWIFTC) $(FLAGS) Sources/MenuToggle.swift Tests/menu-toggle/main.swift -o build/test-menu-toggle
	build/test-menu-toggle
	$(SWIFTC) $(FLAGS) Sources/MenuRefuge.swift Tests/menu-refuge/main.swift -o build/test-menu-refuge
	build/test-menu-refuge
	$(SWIFTC) $(FLAGS) Sources/BrightnessEcho.swift Tests/brightness-echo/main.swift -o build/test-brightness-echo
	build/test-brightness-echo
	$(SWIFTC) $(FLAGS) Sources/QuitNote.swift Tests/quit-note/main.swift -o build/test-quit-note
	build/test-quit-note
	$(SWIFTC) $(FLAGS) Sources/Pointer.swift Tests/pointer/main.swift -o build/test-pointer
	build/test-pointer
	$(SWIFTC) $(FLAGS) Sources/Fonts.swift Tests/fonts/main.swift -o build/test-fonts
	build/test-fonts
	$(SWIFTC) $(FLAGS) Sources/Wording.swift Tests/wording/main.swift -o build/test-wording
	build/test-wording
