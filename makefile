APP=Nerw
BUILD_DIR=.build/debug

main:
	swift build

clean:
	swift package reset
	rm -rf .build

run: bundle
	pkill -x Nerw || true
	open $(BUNDLE_NAME)

debug: bundle
	pkill -x Nerw || true
	./$(MACOS_DIR)/$(APP)

BUNDLE_NAME=$(APP).app
MACOS_DIR=$(BUNDLE_NAME)/Contents/MacOS
RESOURCES_DIR=$(BUNDLE_NAME)/Contents/Resources
ICON_SOURCE=Assets/icon.png
ICON_SET=AppIcon.iconset
ICON_DEST=$(RESOURCES_DIR)/AppIcon.icns

bundle: main
	mkdir -p $(MACOS_DIR)
	mkdir -p $(RESOURCES_DIR)
	cp Info.plist $(BUNDLE_NAME)/Contents/
	cp $(BUILD_DIR)/$(APP) $(MACOS_DIR)/
	mkdir -p $(ICON_SET)
	sips -z 16 16     $(ICON_SOURCE) --out $(ICON_SET)/icon_16x16.png
	sips -z 32 32     $(ICON_SOURCE) --out $(ICON_SET)/icon_16x16@2x.png
	sips -z 32 32     $(ICON_SOURCE) --out $(ICON_SET)/icon_32x32.png
	sips -z 64 64     $(ICON_SOURCE) --out $(ICON_SET)/icon_32x32@2x.png
	sips -z 128 128   $(ICON_SOURCE) --out $(ICON_SET)/icon_128x128.png
	sips -z 256 256   $(ICON_SOURCE) --out $(ICON_SET)/icon_128x128@2x.png
	sips -z 256 256   $(ICON_SOURCE) --out $(ICON_SET)/icon_256x256.png
	sips -z 512 512   $(ICON_SOURCE) --out $(ICON_SET)/icon_256x256@2x.png
	sips -z 512 512   $(ICON_SOURCE) --out $(ICON_SET)/icon_512x512.png
	sips -z 1024 1024 $(ICON_SOURCE) --out $(ICON_SET)/icon_512x512@2x.png
	iconutil -c icns $(ICON_SET)
	cp AppIcon.icns $(ICON_DEST)
	cp -r Resources/* $(RESOURCES_DIR)/ 2>/dev/null || :
	rm -rf $(ICON_SET) AppIcon.icns

clean-bundle:
	rm -rf $(BUNDLE_NAME)
