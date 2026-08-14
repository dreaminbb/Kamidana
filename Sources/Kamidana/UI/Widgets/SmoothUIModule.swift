import SwiftUI

struct SmoothUIModuleModifier: ViewModifier {
    var theme: Theme
    @Environment(\.compactMode) var compactMode: Bool // 環境変数からコンパクトモードを受け取る
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, compactMode ? 8 : 12)
            // 上は6pxのままで、下へ3px分（合計9px）太くする
            .padding(.top, 6)
            .padding(.bottom, 9)
            // ホバー時はsurface1、通常時はbaseの半透明
            .background(isHovered ? theme.surfaceHighlight.opacity(0.8) : theme.background.opacity(0.6))
            // UltraThinMaterialを重ねてガラスのようなぼかし効果を出す
            .background(.ultraThinMaterial)
            .cornerRadius(compactMode ? 8 : 12)
            .overlay(
                RoundedRectangle(cornerRadius: compactMode ? 8 : 12)
                    // ホバー時は薄くボーダーを光らせる
                    .stroke(isHovered ? theme.surfaceBorder : theme.surface, lineWidth: 1)
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
