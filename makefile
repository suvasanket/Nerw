APP=Nerw
BUILD_DIR=.build/debug
CODESIGN_ID ?= LocalDevCert

BUNDLE_NAME=$(APP).app
MACOS_DIR=$(BUNDLE_NAME)/Contents/MacOS
CLI_BIN_DIR=$(BUNDLE_NAME)/Contents/cli_bin
RESOURCES_DIR=$(BUNDLE_NAME)/Contents/Resources
ICON_SOURCE=Assets/icon.png
ICON_SET=AppIcon.iconset
ICON_DEST=$(RESOURCES_DIR)/AppIcon.icns
EXT_ICON_SOURCE=Assets/nerw_ext.png
EXT_ICON_SET=nerw_ext.iconset
EXT_ICON_DEST=$(RESOURCES_DIR)/nerw_ext.icns
MENUBAR_ICON_SOURCE=Assets/iconTemplate.png

# macOS 27 CLT workaround: swift-package has broken @rpath entries that expect
# Xcode's SharedFrameworks dir. Use CLT swift directly (bypasses the SIP-protected
# /usr/bin shim) with DYLD_FRAMEWORK_PATH pointing to the actual framework locations.
CLT_DIR = /Library/Developer/CommandLineTools
SWIFT_PM_DIR = $(CLT_DIR)/usr/lib/swift/pm
SWB_FW_DIR = $(SWIFT_PM_DIR)/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/Frameworks
SWIFT_FW_PATH = $(SWIFT_PM_DIR):$(SWB_FW_DIR):$(SWIFT_PM_DIR)/llbuild

# Use CLT swift directly if it exists, otherwise fall back to system swift
SWIFT_BIN := $(shell [ -x "$(CLT_DIR)/usr/bin/swift" ] && echo "$(CLT_DIR)/usr/bin/swift" || echo "swift")
SWIFT = DYLD_FRAMEWORK_PATH=$(SWIFT_FW_PATH) $(SWIFT_BIN)

main:
	@swift-format format -rip .
	swift-format lint -r . || true
	$(SWIFT) run --disable-sandbox SearchServiceTests
	$(SWIFT) build --disable-sandbox

clean:
	@$(SWIFT) package reset
	@rm -rf .build
	@rm -f Nerw.dmg

open:
	@pkill -x $(APP) || true; sleep 1; open $(BUNDLE_NAME)

run: bundle open
	@echo ""
	@echo "Log file: ~/.nerw/log/nerw-$$(date +%Y-%m-%d).log"
	@echo "View logs with: tail -f ~/.nerw/log/nerw-$$(date +%Y-%m-%d).log"

dev-main:
	$(SWIFT) build --disable-sandbox

bundle-dev: dev-main
	@APP="$(APP)" BUILD_DIR="$(BUILD_DIR)" CODESIGN_ID="$(CODESIGN_ID)" ./Scripts/bundle.sh

run-dev: bundle-dev open
	@echo ""
	@echo "Log file: ~/.nerw/log/nerw-$$(date +%Y-%m-%d).log"
	@echo "View logs with: tail -f ~/.nerw/log/nerw-$$(date +%Y-%m-%d).log"

debug: bundle
	@pkill -x Nerw || true
	@./$(MACOS_DIR)/$(APP)

bundle: main
	@APP="$(APP)" BUILD_DIR="$(BUILD_DIR)" CODESIGN_ID="$(CODESIGN_ID)" ./Scripts/bundle.sh

clean-bundle:
	rm -rf $(BUNDLE_NAME)

dmg-signed: bundle
	@./Scripts/create_dmg.sh

dmg: clean-bundle
	@$(MAKE) bundle CODESIGN_ID=
	@./Scripts/create_dmg.sh
