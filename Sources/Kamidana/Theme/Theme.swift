import SwiftUI

/// アプリ全体のテーマカラーを管理する構造体
public struct Theme {
    public var base: Color
    public var surface0: Color
    public var surface1: Color
    public var surface2: Color
    public var text: Color
    public var subtext0: Color
    public var subtext1: Color
    public var blue: Color
    public var lavender: Color
    public var sapphire: Color
    public var sky: Color
    public var teal: Color
    public var green: Color
    public var yellow: Color
    public var peach: Color
    public var maroon: Color
    public var red: Color
    public var mauve: Color
    public var pink: Color
    public var flamingo: Color
    public var rosewater: Color
}

public extension Theme {
    /// Catppuccin Mocha テーマの定義
    static let catppuccinMocha = Theme(
        base: Color(hex: "#1e1e2e"),
        surface0: Color(hex: "#313244"),
        surface1: Color(hex: "#45475a"),
        surface2: Color(hex: "#585b70"),
        text: Color(hex: "#cdd6f4"),
        subtext0: Color(hex: "#a6adc8"),
        subtext1: Color(hex: "#bac2de"),
        blue: Color(hex: "#89b4fa"),
        lavender: Color(hex: "#b4befe"),
        sapphire: Color(hex: "#74c7ec"),
        sky: Color(hex: "#89dceb"),
        teal: Color(hex: "#94e2d5"),
        green: Color(hex: "#a6e3a1"),
        yellow: Color(hex: "#f9e2af"),
        peach: Color(hex: "#fab387"),
        maroon: Color(hex: "#eba0ac"),
        red: Color(hex: "#f38ba8"),
        mauve: Color(hex: "#cba6f7"),
        pink: Color(hex: "#f5c2e7"),
        flamingo: Color(hex: "#f2cdcd"),
        rosewater: Color(hex: "#f5e0dc")
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
