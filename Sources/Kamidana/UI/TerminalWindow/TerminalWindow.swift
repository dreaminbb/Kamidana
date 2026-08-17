import SwiftTerm
import SwiftUI

/// A description
/// ```swift
/// TerminalView(executable: "/opt/homebrew/bin/btop")
///     .background(Color(hex: colors.base).opacity(0.6)) // Kamidanaのテーマ色で半透明
///     .background(.ultraThinMaterial)      // すりガラス効果
/// ```
struct TerminalView: NSViewRepresentable {

    var executable: String

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
        let colors = ConfigManager.shared.currentConfig.colors
        terminal.nativeForegroundColor = NSColor(Color(hex: colors.textPrimary))

        let ansiColors: [SwiftTerm.Color] = [
            SwiftTerm.Color(nsColor: NSColor(Color(hex: colors.surface))),
            SwiftTerm.Color(nsColor: NSColor(Color(hex: colors.danger))),
            SwiftTerm.Color(nsColor: NSColor(Color(hex: colors.success))),
            SwiftTerm.Color(nsColor: NSColor(Color(hex: colors.warning))),
            SwiftTerm.Color(nsColor: NSColor(Color(hex: colors.primary))),
            SwiftTerm.Color(nsColor: NSColor(Color(hex: colors.secondary))),
            SwiftTerm.Color(nsColor: NSColor(Color(hex: colors.info))),
            SwiftTerm.Color(nsColor: NSColor(Color(hex: colors.textSecondary))),

            SwiftTerm.Color(nsColor: NSColor(Color(hex: colors.surfaceHighlight))),
            SwiftTerm.Color(nsColor: NSColor(Color(hex: colors.danger))),
            SwiftTerm.Color(nsColor: NSColor(Color(hex: colors.success))),
            SwiftTerm.Color(nsColor: NSColor(Color(hex: colors.warning))),
            SwiftTerm.Color(nsColor: NSColor(Color(hex: colors.primary))),
            SwiftTerm.Color(nsColor: NSColor(Color(hex: colors.secondary))),
            SwiftTerm.Color(nsColor: NSColor(Color(hex: colors.info))),
            SwiftTerm.Color(nsColor: NSColor(Color(hex: colors.textPrimary)))
        ]

        terminal.installColors(ansiColors)
    }
}
