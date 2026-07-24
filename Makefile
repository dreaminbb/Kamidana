.PHONY: build run app clean

APP_NAME = Kamidana
BUILD_PATH = .build/release/$(APP_NAME)
APP_DIR = $(APP_NAME).app
MACOS_DIR = $(APP_DIR)/Contents/MacOS

# 開発用の通常実行
run:
	swift run

# リリースビルド
build:
	swift build -c release

# macOSの .app バンドルを作成する
app: build
	mkdir -p $(MACOS_DIR)
	cp $(BUILD_PATH) $(MACOS_DIR)/$(APP_NAME)
	# Info.plistを作成（メニューバー専用アプリとしてDockにアイコンを出さない設定など）
	echo '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n\t<key>CFBundleExecutable</key>\n\t<string>$(APP_NAME)</string>\n\t<key>CFBundleIdentifier</key>\n\t<string>com.shin.Kamidana</string>\n\t<key>CFBundleName</key>\n\t<string>$(APP_NAME)</string>\n\t<key>CFBundleShortVersionString</key>\n\t<string>1.0</string>\n\t<key>LSUIElement</key>\n\t<true/>\n</dict>\n</plist>' > $(APP_DIR)/Contents/Info.plist
	@echo "✨ Created $(APP_DIR)"
	@echo "You can now run: open $(APP_DIR)"

clean:
	rm -rf .build
	rm -rf $(APP_DIR)
