all:
	xcodegen generate
	xcodebuild -configuration Release -alltargets SYMROOT="$(CURDIR)/build"

codesign: all
	../scripts/codesign.sh build/Release

clean:
	rm -rf build
	rm -rf *.xcodeproj

run: codesign
	open ./build/Release/AccessibilityMonitorExample.app
