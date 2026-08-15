import SwiftUI

struct SmoothUIModuleModifier: ViewModifier {
    var theme: Theme
    @Environment(\.compactMode) var compactMode: Bool // Receive compact mode from environment
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, compactMode ? 8 : 12)
            // Keep top at 6px and thicken bottom by 3px (total 9px)
            .padding(.top, 6)
            .padding(.bottom, 9)
            // On hover use surfaceHighlight, normally use semi-transparent background
            .background(isHovered ? theme.surfaceHighlight.opacity(0.8) : theme.background.opacity(0.6))
            // Layer UltraThinMaterial for a glass-like blur effect
            .background(.ultraThinMaterial)
            .cornerRadius(compactMode ? 8 : 12)
            .overlay(
                RoundedRectangle(cornerRadius: compactMode ? 8 : 12)
                    // Highlight border subtly on hover
                    .stroke(isHovered ? theme.surfaceBorder : theme.surface, lineWidth: 1)
            )
            // Hover animation
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
