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

.PHONY: app run install uninstall clean
install: app
	rm -rf "$(PREFIX)/Curtain.app"
	cp -R "$(APP)" "$(PREFIX)/Curtain.app"

uninstall:
	rm -rf "$(PREFIX)/Curtain.app"

clean:
	rm -rf build
