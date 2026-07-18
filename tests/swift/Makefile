all:
	xcodegen generate
	xcodebuild test -scheme AccessibilityMonitorTests -destination 'platform=macOS' SYMROOT="$(CURDIR)/build"

clean:
	rm -rf build
	rm -rf *.xcodeproj
