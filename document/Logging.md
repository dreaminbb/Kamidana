# Logging (Rich Console / Debug)

Kamidana のリッチなコンソール出力は `DebugRichConsole` に集約されています。  
このツールはデバッグ専用です（`DEBUG` ビルドのみデフォルト有効）。

## 使い方

任意のファイルから以下のように呼び出します。

```swift
DebugRichConsole.printSystemMatrix(newData)
```

## 有効/無効の切り替え

出力の有効化は `DebugRichConsole.isEnabled` で制御します。

```swift
DebugRichConsole.isEnabled = true   // 出力する
DebugRichConsole.isEnabled = false  // 出力しない
```

## 追加の方針

新しいログ表示を増やす場合は、`print(...)` を各所に散らさず `DebugRichConsole` に実装してください。  
バイト表示は `DebugRichConsole.formatBytes(_:)` を共通利用します。
