import SwiftUI

struct SmoothUIModuleModifier: ViewModifier {
    @Environment(\.compactMode) var compactMode: Bool // Receive compact mode from environment
    @State private var isHovered = false

    func body(content: Content) -> some View {
        let config = compactMode ? ConfigManager.shared.currentConfig.styleCompact : ConfigManager.shared.currentConfig.styleNormal
        let colors = ConfigManager.shared.currentConfig.colors
        return content
            .padding(.horizontal, config.paddingHorizontal)
            // Keep top at 6px and thicken bottom by 3px (total 9px)
            .padding(.top, config.paddingTop)
            .padding(.bottom, config.paddingBottom)
            // On hover use surfaceHighlight, normally use semi-transparent background
            .background(isHovered ? Color(hex: colors.surfaceHighlight).opacity(config.hoverBackgroundColorOpacity) : Color(hex: colors.background).opacity(config.backgroundColorOpacity))
            // Layer UltraThinMaterial for a glass-like blur effect
            .background(.ultraThinMaterial)
            .cornerRadius(config.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: config.cornerRadius)
                    // Highlight border subtly on hover
                    .stroke(isHovered ? Color(hex: colors.surfaceBorder) : Color(hex: colors.surface), lineWidth: 1)
            )
            // Hover animation
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }

    }
}

extension View {
    func SmoothUIModule() -> some View {
        self.modifier(SmoothUIModuleModifier())
    }
}
