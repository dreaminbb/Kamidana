import SwiftUI

struct IsInsideWidgetFolderKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isInsideWidgetFolder: Bool {
        get { self[IsInsideWidgetFolderKey.self] }
        set { self[IsInsideWidgetFolderKey.self] = newValue }
    }
}

struct SmoothUIModuleModifier: ViewModifier {
    @Environment(\.widgetStyle) var style: WidgetStyleConfig
    @Environment(\.isInsideWidgetFolder) var isInsideWidgetFolder: Bool
    @State private var isHovered = false

    func body(content: Content) -> some View {
        let colors = ConfigManager.shared.currentConfig.colors

        if isInsideWidgetFolder {
            return AnyView(content)
        }

        return AnyView(content
            .padding(.horizontal, style.paddingHorizontal)
            // Keep top at 6px and thicken bottom by 3px (total 9px)
            .padding(.top, style.paddingTop)
            .padding(.bottom, style.paddingBottom)
            // On hover use surfaceHighlight, normally use semi-transparent background
            .background(isHovered ? Color(hex: colors.surfaceHighlight).opacity(style.hoverBackgroundColorOpacity) : Color(hex: colors.background).opacity(style.backgroundColorOpacity))
            // Layer UltraThinMaterial for a glass-like blur effect
            .background(.ultraThinMaterial)
            .cornerRadius(style.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    // Highlight border subtly on hover
                    .stroke(isHovered ? Color(hex: colors.surfaceBorder) : Color(hex: colors.surface), lineWidth: 1)
            )
            // Hover animation
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            })
    }
}

struct WidgetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .SmoothUIModule()
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

extension View {
    func SmoothUIModule() -> some View {
        self.modifier(SmoothUIModuleModifier())
    }
}
