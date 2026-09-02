APP_NAME := MenuHarbor
CONFIGURATION := release
BUILD_DIR := .build/$(CONFIGURATION)
BUNDLE := $(BUILD_DIR)/$(APP_NAME).app

.PHONY: app run test clean

app:
	swift build -c $(CONFIGURATION)
	rm -rf "$(BUNDLE)"
	mkdir -p "$(BUNDLE)/Contents/MacOS" "$(BUNDLE)/Contents/Resources"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp Info.plist "$(BUNDLE)/Contents/Info.plist"
	codesign --force --sign - "$(BUNDLE)"
	@echo "Built $(BUNDLE)"

run: app
	open "$(BUNDLE)"

test:
	swift test

clean:
	swift package clean

