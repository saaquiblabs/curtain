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
# and the Accessibility list. Signed ad hoc (no Apple account needed) so the signature carries
# our bundle ID and the Accessibility permission sticks.
app: build/curtain Resources/Info.plist
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp build/curtain "$(APP)/Contents/MacOS/curtain"
	sed 's/@VERSION@/$(VERSION)/g' Resources/Info.plist > "$(APP)/Contents/Info.plist"
	if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$(APP)/Contents/Resources/"; fi
	codesign --force --sign - --identifier $(BUNDLE_ID) "$(APP)"

run: app
	-pkill -x curtain
	open "$(APP)"

.PHONY: app run install uninstall clean renders theme-check test
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
