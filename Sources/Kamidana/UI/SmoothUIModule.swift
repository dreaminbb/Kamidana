import SwiftUI

struct SmoothUIModuleModifier: ViewModifier {
    var theme: Theme
    @Environment(\.compactMode) var compactMode: Bool // 環境変数からコンパクトモードを受け取る
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, compactMode ? 8 : 12)
            // 高さは変えないため、垂直方向のパディングは6で固定
            .padding(.vertical, 6)
            // ホバー時はsurface1、通常時はbaseの半透明
            .background(isHovered ? theme.surface1.opacity(0.8) : theme.base.opacity(0.6))
            // UltraThinMaterialを重ねてガラスのようなぼかし効果を出す
            .background(.ultraThinMaterial)
            .cornerRadius(compactMode ? 8 : 12)
            .overlay(
                RoundedRectangle(cornerRadius: compactMode ? 8 : 12)
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
    func SmoothUIModule(theme: Theme = .catppuccinMocha) -> some View {
        self.modifier(SmoothUIModuleModifier(theme: theme))
    }
}
