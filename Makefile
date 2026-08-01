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

# macOSの .app バンドルを作成する（本番リリース用）
app:
	swift build -c release
	mkdir -p $(MACOS_DIR)
	cp .build/release/$(APP_NAME) $(MACOS_DIR)/$(APP_NAME)
	# Info.plistを作成
	echo '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n\t<key>CFBundleExecutable</key>\n\t<string>$(APP_NAME)</string>\n\t<key>CFBundleIdentifier</key>\n\t<string>com.shin.Kamidana</string>\n\t<key>CFBundleName</key>\n\t<string>$(APP_NAME)</string>\n\t<key>CFBundleShortVersionString</key>\n\t<string>1.0</string>\n\t<key>LSUIElement</key>\n\t<true/>\n\t<key>NSLocationWhenInUseUsageDescription</key>\n\t<string>周辺のWi-Fiネットワークを検索して表示するために位置情報を使用します。</string>\n\t<key>NSLocationUsageDescription</key>\n\t<string>周辺のWi-Fiネットワークを検索して表示するために位置情報を使用します。</string>\n</dict>\n</plist>' > $(APP_DIR)/Contents/Info.plist
	@echo "✨ Created Release $(APP_DIR)"

# ターミナル上でログを見ながら実行するデバッグモード（DEBUGフラグ付き）
debug:
	swift build
	mkdir -p $(MACOS_DIR)
	cp .build/debug/$(APP_NAME) $(MACOS_DIR)/$(APP_NAME)
	echo '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n\t<key>CFBundleExecutable</key>\n\t<string>$(APP_NAME)</string>\n\t<key>CFBundleIdentifier</key>\n\t<string>com.shin.Kamidana</string>\n\t<key>CFBundleName</key>\n\t<string>$(APP_NAME)</string>\n\t<key>CFBundleShortVersionString</key>\n\t<string>1.0</string>\n\t<key>LSUIElement</key>\n\t<true/>\n\t<key>NSAppleEventsUsageDescription</key>\n\t<string>音楽プレイヤーの再生情報を取得するためにAppleScriptを使用します。</string>\n\t<key>NSLocationWhenInUseUsageDescription</key>\n\t<string>周辺のWi-Fiネットワークを検索して表示するために位置情報を使用します。</string>\n\t<key>NSLocationUsageDescription</key>\n\t<string>周辺のWi-Fiネットワークを検索して表示するために位置情報を使用します。</string>\n</dict>\n</plist>' > $(APP_DIR)/Contents/Info.plist
	codesign --force --deep --sign - $(APP_DIR)
	@echo "🐛 Starting Kamidana in debug mode... (Press Ctrl+C to stop)"
	./$(MACOS_DIR)/$(APP_NAME)

clean:
	rm -rf .build
	rm -rf $(APP_DIR)
