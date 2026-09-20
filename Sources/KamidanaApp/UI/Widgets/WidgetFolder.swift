import SwiftUI

struct WidgetFolder: View {
  @Environment(\.kamidanaWidgetAnimation) private var animation
  @Environment(\.kamidanaWidgetActivation) private var widgetActivation
  @Environment(\.theme) private var theme
  @Environment(\.popupTheme) private var popupTheme
  let config: WidgetFolderConfig
  private let verticalContentWidth: CGFloat = 220

  @State private var isExpandedInline: Bool = false
  @StateObject private var interaction = WidgetInteractionController()

  var body: some View {
    let isExpanded = config.direction == "below" ? interaction.isPresented : isExpandedInline
    let fallbackIcon = config.icon ?? "󰉋"
    let foldedIcon = config.iconFolded ?? fallbackIcon
    let folderIcon = isExpanded ? fallbackIcon : foldedIcon
    let iconColor = theme?.iconForeground ?? Color(hex: config.iconColor)

    Group {
      if config.direction == "below" {
        WidgetActionButton(action: { interaction.activate(activation) }) {
          HStack(spacing: 4) {
            NerdFontIcon(folderIcon).foregroundColor(iconColor)
            if let name = config.name { Text(name).foregroundColor(iconColor) }
          }
        }
        .widgetInteraction(controller: interaction, activation: activation) { _ in
          VStack(alignment: .leading, spacing: 8) {
            if let name = config.name {
              Text(name)
                .font(.headline)
                .foregroundColor(
                  Color(hex: ConfigManager.shared.currentConfig.colors.textPrimary))
            }
            nestedWidgets(fillWidth: true)
              .focusable(false)
          }
          .padding()
          .frame(width: verticalContentWidth, alignment: .leading)
        }
      } else {
        HStack(spacing: 8) {
          if config.direction == "left" && isExpanded {
            nestedWidgets()
              .transition(expansionTransition(edge: .trailing))
          }

          WidgetActionButton(action: { toggleExpansion($isExpandedInline) }) {
            HStack(spacing: 4) {
              NerdFontIcon(folderIcon).foregroundColor(iconColor)
              if let name = config.name { Text(name).foregroundColor(iconColor) }
            }
          }

          if config.direction == "right" && isExpanded {
            nestedWidgets()
              .transition(expansionTransition(edge: .leading))
          }
        }
        .environment(\.isInsideWidgetFolder, true)
        .environment(\.theme, isExpandedInline ? popupTheme ?? theme : theme)
        .SmoothUIModule(theme: isExpandedInline ? popupTheme ?? theme : theme)
      }
    }
  }

  @ViewBuilder
  func nestedWidgets(fillWidth: Bool = false) -> some View {
    ForEach(config.widgets, id: \.id) { instance in
      if let factory = WidgetRegistry.shared.factory(for: instance.typeID) {
        if fillWidth {
          factory.makeView(config: instance.config)
            .environment(\.theme, instance.theme)
            .environment(\.popupTheme, instance.popupTheme)
            .environment(\.kamidanaWidgetFormat, instance.v1Format)
            .environment(\.kamidanaWidgetActivation, instance.v1Activate)
            .kamidanaWidgetAnimation(instance.v1Animation)
            .environment(\.isInsideWidgetFolder, true)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          factory.makeView(config: instance.config)
            .environment(\.theme, instance.theme)
            .environment(\.popupTheme, instance.popupTheme)
            .environment(\.kamidanaWidgetFormat, instance.v1Format)
            .environment(\.kamidanaWidgetActivation, instance.v1Activate)
              .kamidanaWidgetAnimation(instance.v1Animation)
            .environment(\.isInsideWidgetFolder, true)
        }
      }
    }
  }

  private var activation: KamidanaActivation {
    widgetActivation ?? .click
  }

  private func toggleExpansion(_ isExpanded: Binding<Bool>) {
    if animation == .dynamic {
      withAnimation((theme?.motion ?? .standard).expand.resolvedAnimation()) {
        isExpanded.wrappedValue.toggle()
      }
    } else {
      var transaction = Transaction()
      transaction.disablesAnimations = true
      withTransaction(transaction) {
        isExpanded.wrappedValue.toggle()
      }
    }
  }

  private func expansionTransition(edge: Edge) -> AnyTransition {
    guard animation == .dynamic else { return .identity }
    return .move(edge: edge).combined(with: .opacity)
  }
}
