import SwiftUI

/// アプリ全体のテーマカラーを管理する構造体
/// CSSのように一貫性のあるセマンティックな変数名を使用します。
public struct Theme {
    // Backgrounds & Surfaces
    public var background: Color
    public var surface: Color
    public var surfaceHighlight: Color
    public var surfaceBorder: Color

    // Typography
    public var textPrimary: Color
    public var textSecondary: Color
    public var textTertiary: Color

    // Semantic Colors
    public var primary: Color
    public var secondary: Color
    public var accent: Color
    public var success: Color
    public var warning: Color
    public var danger: Color
    public var info: Color
    public var caution: Color
}

public extension Theme {
    /// Catppuccin Mocha テーマの定義
    static let catppuccinMocha = Theme(
        background: Color(hex: "#1e1e2e"),       // base
        surface: Color(hex: "#313244"),          // surface0
        surfaceHighlight: Color(hex: "#45475a"), // surface1
        surfaceBorder: Color(hex: "#585b70"),    // surface2
        
        textPrimary: Color(hex: "#cdd6f4"),      // text
        textSecondary: Color(hex: "#bac2de"),    // subtext1
        textTertiary: Color(hex: "#a6adc8"),     // subtext0
        
        primary: Color(hex: "#89b4fa"),          // blue
        secondary: Color(hex: "#cba6f7"),        // mauve
        accent: Color(hex: "#f5c2e7"),           // pink
        success: Color(hex: "#a6e3a1"),          // green
        warning: Color(hex: "#fab387"),          // peach
        danger: Color(hex: "#f38ba8"),           // red
        info: Color(hex: "#94e2d5"),             // teal
        caution: Color(hex: "#f9e2af")           // yellow
    )
}

// 16進数カラーコードをSwiftUIのColorに変換する拡張
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
