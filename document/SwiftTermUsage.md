# SwiftTerm を使った独自ターミナル実装ガイド (Kamidana向け)

このドキュメントは、SwiftUI (macOS) 環境の Kamidana アプリ内に、`SwiftTerm` を使って独自テーマ・半透明のターミナルウィンドウを組み込み、`btop` や `fastfetch` を表示するための実装手順とポイントをまとめたものです。

## 1. SwiftTerm のコアコンポーネント

SwiftTermはプラットフォームごとにビューを提供しています。macOSにおいて、ローカルのシェルプロセス（コマンド）を直接実行・描画するために使用するのは **`LocalProcessTerminalView`**（`NSView`のサブクラス）です。

## 2. 導入と SwiftUI への組み込み

### パッケージの追加
`Package.swift` の dependencies に以下を追加します。
`https://github.com/migueldeicaza/SwiftTerm.git`

### SwiftUI ラッパー (NSViewRepresentable) の作成
SwiftUIで表示するためには `NSViewRepresentable` でラップします。

```swift
import SwiftUI
import SwiftTerm

struct TerminalView: NSViewRepresentable {
    var executable: String
    var theme: Theme
    
    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminal = LocalProcessTerminalView()
        
        // 【重要】GUIアプリからはHomebrewのPATHが通っていないため、絶対パスを指定する
        terminal.startProcess(executable: executable, args: [])
        
        // テーマとデザインの適用（後述）
        applyTheme(to: terminal)
        
        return terminal
    }
    
    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}
}
```

## 3. デザインとテーマのカスタマイズ（重要）

今回の要件である「アプリのテーマに合わせた配色」と「半透明な背景」を実現するための設定項目です。

### A. 背景の半透明化
ターミナル自体の背景を透明にし、SwiftUI側の修飾子でガラス効果（`ultraThinMaterial`）を出します。

```swift
// SwiftTerm 側の背景を透明に
terminal.nativeBackgroundColor = NSColor.clear
terminal.isTransparent = true // 背景描画を透過させる
```

SwiftUI側での呼び出し時：
```swift
TerminalView(executable: "/opt/homebrew/bin/btop", theme: theme)
    .background(theme.base.opacity(0.6)) // Kamidanaのテーマ色で半透明
    .background(.ultraThinMaterial)      // すりガラス効果
```

### B. カラースキーム（ANSIカラー）の上書き
`btop` や `fastfetch` が出力する色を、KamidanaのCatppuccinテーマと完全に一致させるためには、ターミナルのカラーパレット（ANSI 16色）を上書きします。

```swift
func applyTheme(to terminal: LocalProcessTerminalView) {
    // 1. 基本となる文字色
    terminal.nativeForegroundColor = NSColor(theme.text)
    
    // 2. ANSIカラーパレット（16色）の上書き
    // ターミナルが「赤」や「青」として出力する色を、Kamidanaのカスタムカラーに差し替える
    let ansiColors: [NSColor] = [
        NSColor(theme.surface0), // 0: Black
        NSColor(theme.red),      // 1: Red
        NSColor(theme.green),    // 2: Green
        NSColor(theme.yellow),   // 3: Yellow
        NSColor(theme.blue),     // 4: Blue
        NSColor(theme.mauve),    // 5: Magenta
        NSColor(theme.teal),     // 6: Cyan
        NSColor(theme.subtext1), // 7: White
        // --- 以下、Brightカラーも同系色または少し明るい色をマッピング ---
        NSColor(theme.surface1), // 8: Bright Black
        NSColor(theme.red),      // 9: Bright Red
        NSColor(theme.green),    // 10: Bright Green
        NSColor(theme.peach),    // 11: Bright Yellow
        NSColor(theme.blue),     // 12: Bright Blue
        NSColor(theme.mauve),    // 13: Bright Magenta
        NSColor(theme.teal),     // 14: Bright Cyan
        NSColor(theme.text)      // 15: Bright White
    ]
    
    // SwiftTermのパレットに適用
    terminal.installColors(colors: ansiColors)
}
```

## 4. ウィンドウの呼び出し方

メインの `KamidanaApp.swift` に、ターミナル専用の新しい `WindowGroup` を追加します。

```swift
WindowGroup("System Monitor", id: "BtopWindow") {
    TerminalView(executable: "/opt/homebrew/bin/btop", theme: Theme.catppuccinMocha)
        .frame(width: 800, height: 600)
}
.windowStyle(.hiddenTitleBar) // タイトルバーを消してクールにする
```

あとは、ウィジェットのボタンから `openWindow(id: "BtopWindow")` を呼び出すだけで、テーマが完全に統一された美しいネイティブターミナルが瞬時に立ち上がります。
