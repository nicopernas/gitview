PREFIX ?= $(HOME)/.local
# Command Line Tools ship the Swift Testing macros but don't search for them.
TESTING_PLUGINS := $(wildcard /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing)
TEST_FLAGS := $(if $(TESTING_PLUGINS),-Xswiftc -plugin-path -Xswiftc $(TESTING_PLUGINS))

.PHONY: build test run install clean

build:
	swift build -c release

test:
	swift test $(TEST_FLAGS)

run:
	swift build
	GITVIEW_FOREGROUND=1 $$(swift build --show-bin-path)/gitview $(ARGS)

install: build
	install -d $(PREFIX)/bin
	install $$(swift build -c release --show-bin-path)/gitview $(PREFIX)/bin/gitview

clean:
	rm -rf .build
