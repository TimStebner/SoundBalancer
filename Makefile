.PHONY: all build app run clean

SDK_PATH = /Library/Developer/CommandLineTools/SDKs/MacOSX27.0.sdk

all: app

build:
	mkdir -p /tmp/clang-cache
	swift build -c release --sdk $(SDK_PATH) -Xswiftc -target -Xswiftc arm64-apple-macos27.0 -Xswiftc -module-cache-path -Xswiftc /tmp/clang-cache

app:
	./scripts/package_app.sh release

app-debug:
	./scripts/package_app.sh debug

run: app
	open build/SoundBalancer.app

clean:
	rm -rf .build build
