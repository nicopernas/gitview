PREFIX ?= $(HOME)/.local
APP := $(PREFIX)/share/gitview/gitview.app
# Command Line Tools ship the Swift Testing macros but don't search for them.
TESTING_PLUGINS := $(wildcard /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing)
TEST_FLAGS := $(if $(TESTING_PLUGINS),-Xswiftc -plugin-path -Xswiftc $(TESTING_PLUGINS))

.PHONY: build test run install clean icon

build:
	swift build -c release

test:
	swift test $(TEST_FLAGS)

run:
	swift build
	GITVIEW_FOREGROUND=1 $$(swift build --show-bin-path)/gitview $(ARGS)

# The binary lives in an .app so macOS can launch it as a normal app.
install: build
	rm -rf $(APP)
	install -d $(APP)/Contents/MacOS $(PREFIX)/bin
	install -d $(APP)/Contents/Resources
	install -m 644 app/Info.plist $(APP)/Contents/Info.plist
	install -m 644 app/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	install $$(swift build -c release --show-bin-path)/gitview $(APP)/Contents/MacOS/gitview
	codesign --force --sign - $(APP)
	ln -sf $(APP)/Contents/MacOS/gitview $(PREFIX)/bin/gitview

clean:
	rm -rf .build

# Redraws app/AppIcon.icns from app/make-icon.swift.
icon:
	rm -rf .build/AppIcon.iconset && mkdir -p .build/AppIcon.iconset
	swiftc -O app/make-icon.swift -o .build/make-icon
	for s in 16 32 128 256 512; do \
		.build/make-icon $$s .build/AppIcon.iconset/icon_$${s}x$${s}.png; \
		.build/make-icon $$((s * 2)) .build/AppIcon.iconset/icon_$${s}x$${s}@2x.png; \
	done
	iconutil -c icns .build/AppIcon.iconset -o app/AppIcon.icns
