r# Compact UI

内蔵ディスプレイ時のコンパクト表示は `UISettingsStore` で管理します。

## 設定変数

- `displayModePolicy`
  - `.auto`: built-in 判定時のみ compact
  - `.alwaysCompact`: 常に compact
  - `.alwaysRegular`: 常に通常表示
- `collapsedWidgets`
  - compact 時に折りたたむウィジェットの集合
  - 初期値: `disk`, `gpu`

## 保存先

`UserDefaults` の以下キーに永続化されます。

- `ui.displayModePolicy`
- `ui.collapsedWidgets`

## 判定ロジック

- `DisplayDetector.isBuiltInMainDisplay()`
  - `NSScreen.main` から `NSScreenNumber` を取得
  - `CGDisplayIsBuiltin` で built-in 判定

## UI挙動

- compact 判定時はフォントと間隔を縮小
- 右側は **CPU / Memory のみ常時表示**
- その他（Network / GPU / Disk / Battery / Clock）は `list.bullet` アイコン配下に折りたたみ
- Audio codec は常時表示せず、popover 内でのみ表示
- Music は左側グループに置き、Wi-Fiの左に表示
