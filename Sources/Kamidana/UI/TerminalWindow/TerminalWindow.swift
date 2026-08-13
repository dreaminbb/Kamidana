import SwiftTerm
import SwiftUI

/// A description
/// ```swift
/// TerminalView(executable: "/opt/homebrew/bin/btop", theme: theme)
///     .background(theme.base.opacity(0.6)) // Kamidanaのテーマ色で半透明
///     .background(.ultraThinMaterial)      // すりガラス効果
/// ```
struct TerminalView: NSViewRepresentable {

    var executable: String
    var theme: Theme

    func makeNSView(context: Context) -> LocalProcessTerminalView {

        let terminal = LocalProcessTerminalView(frame: .zero)

        // 背景を透明にして、すりガラス効果などを適用できるようにする
        terminal.nativeBackgroundColor = NSColor.clear

        terminal.startProcess(executable: executable, args: [])

        applyTheme(to: terminal)

        return terminal
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}

    // テーマカラーをターミナルのANSIカラーパレットに適用する
    func applyTheme(to terminal: LocalProcessTerminalView) {
        terminal.nativeForegroundColor = NSColor(theme.textPrimary)

        let ansiColors: [SwiftTerm.Color] = [
            SwiftTerm.Color(nsColor: NSColor(theme.surface)),
            SwiftTerm.Color(nsColor: NSColor(theme.danger)),
            SwiftTerm.Color(nsColor: NSColor(theme.success)),
            SwiftTerm.Color(nsColor: NSColor(theme.warning)),
            SwiftTerm.Color(nsColor: NSColor(theme.primary)),
            SwiftTerm.Color(nsColor: NSColor(theme.secondary)),
            SwiftTerm.Color(nsColor: NSColor(theme.info)),
            SwiftTerm.Color(nsColor: NSColor(theme.textSecondary)),

            SwiftTerm.Color(nsColor: NSColor(theme.surfaceHighlight)),
            SwiftTerm.Color(nsColor: NSColor(theme.danger)),
            SwiftTerm.Color(nsColor: NSColor(theme.success)),
            SwiftTerm.Color(nsColor: NSColor(theme.warning)),
            SwiftTerm.Color(nsColor: NSColor(theme.primary)),
            SwiftTerm.Color(nsColor: NSColor(theme.secondary)),
            SwiftTerm.Color(nsColor: NSColor(theme.info)),
            SwiftTerm.Color(nsColor: NSColor(theme.textPrimary))
        ]

        terminal.installColors(ansiColors)
    }
}
