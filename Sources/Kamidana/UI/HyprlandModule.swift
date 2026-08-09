import SwiftUI

/// Hyprland風の角丸・半透明・ホバー効果を持つモジュール用の共通モディファイア
struct HyprlandModuleModifier: ViewModifier {
    var theme: Theme
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            // ホバー時はsurface1、通常時はbaseの半透明
            .background(isHovered ? theme.surface1.opacity(0.8) : theme.base.opacity(0.6))
            // UltraThinMaterialを重ねてガラスのようなぼかし効果を出す
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    // ホバー時は薄くボーダーを光らせる
                    .stroke(isHovered ? theme.surface2 : theme.surface0, lineWidth: 1)
            )
            // ホバー時のアニメーション
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    /// ViewをHyprland風のモジュールデザインにする拡張メソッド
    func hyprlandModule(theme: Theme = .catppuccinMocha) -> some View {
        self.modifier(HyprlandModuleModifier(theme: theme))
    }
}
