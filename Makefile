APP_NAME := MenuHarbor
CONFIGURATION := release
BUILD_DIR := .build/$(CONFIGURATION)
BUNDLE := $(BUILD_DIR)/$(APP_NAME).app

.PHONY: app run test icon clean

app:
	swift build -c $(CONFIGURATION)
	rm -rf "$(BUNDLE)"
	mkdir -p "$(BUNDLE)/Contents/MacOS" "$(BUNDLE)/Contents/Resources"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp Info.plist "$(BUNDLE)/Contents/Info.plist"
	cp Resources/AppIcon.icns "$(BUNDLE)/Contents/Resources/"
	codesign --force --sign - "$(BUNDLE)"
	@echo "Built $(BUNDLE)"

run: app
	open "$(BUNDLE)"

test:
	swift test

icon:
	swift scripts/make-icon.swift
	iconutil -c icns scripts/icon.iconset -o Resources/AppIcon.icns

clean:
	swift package clean

