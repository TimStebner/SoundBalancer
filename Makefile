.PHONY: all build app app-debug dmg run clean

SDK_PATH ?= $(shell xcrun --show-sdk-path 2>/dev/null || echo /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk)
TARGET ?= arm64-apple-macos15.0

all: app

build:
	mkdir -p /tmp/clang-cache
	swift build -c release --sdk $(SDK_PATH) -Xswiftc -target -Xswiftc $(TARGET) -Xswiftc -module-cache-path -Xswiftc /tmp/clang-cache

app:
	./scripts/package_app.sh release

app-debug:
	./scripts/package_app.sh debug

dmg:
	./scripts/create_dmg.sh

run: app
	open build/SoundBalancer.app

clean:
	rm -rf .build build
