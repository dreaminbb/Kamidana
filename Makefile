.PHONY: build run app debug clean

APP_NAME = Kamidana
BUILD_PRODUCT = KamidanaApp
BUILD_PATH = .build/release/$(BUILD_PRODUCT)
APP_DIR = $(APP_NAME).app
CONTENTS_DIR = $(APP_DIR)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = Resources
ENTITLEMENTS_FILE = $(RESOURCES_DIR)/Kamidana.entitlements

# Run Kamidana directly for development
run:
	swift run $(BUILD_PRODUCT)

# Build release binary
build:
	swift build -c release

# Build and package the macOS .app bundle for production release
app:
	swift build -c release
	mkdir -p $(MACOS_DIR)
	cp .build/release/$(BUILD_PRODUCT) $(MACOS_DIR)/$(APP_NAME)
	cp $(RESOURCES_DIR)/Info.plist $(CONTENTS_DIR)/Info.plist
	codesign --force --deep --options runtime --entitlements $(ENTITLEMENTS_FILE) --sign - $(APP_DIR)
	@echo "Created Release $(APP_DIR)"

# Build and run in debug mode with terminal logs
debug:
	swift build
	mkdir -p $(MACOS_DIR)
	cp .build/debug/$(BUILD_PRODUCT) $(MACOS_DIR)/$(APP_NAME)
	cp $(RESOURCES_DIR)/Info.plist $(CONTENTS_DIR)/Info.plist
	codesign --force --deep --options runtime --entitlements $(ENTITLEMENTS_FILE) --sign - $(APP_DIR)
	@echo "Starting Kamidana in debug mode... (Press Ctrl+C to stop)"
	./$(MACOS_DIR)/$(APP_NAME)

# Clean build artifacts and app bundle
clean:
	rm -rf .build
	rm -rf $(APP_DIR)
