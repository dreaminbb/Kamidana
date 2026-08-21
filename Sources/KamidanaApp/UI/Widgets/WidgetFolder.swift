import SwiftUI

struct WidgetFolder: View {
  @Environment(\.kamidanaWidgetMotion) private var motion
  @Environment(\.kamidanaWidgetActivation) private var widgetActivation
  @Environment(\.kamidanaV1Style) private var v1Style
  @Environment(\.kamidanaPopupStyle) private var popupStyle
  let config: WidgetFolderConfig
  private let verticalContentWidth: CGFloat = 220

  @State private var isExpandedInline: Bool = false
  @State private var showPopover = false
  @State private var hoverState = WidgetPopoverHoverState()

  var body: some View {
    let isExpanded = config.direction == "below" ? showPopover : isExpandedInline
    let fallbackIcon = config.icon ?? "󰉋"
    let foldedIcon = config.iconFolded ?? fallbackIcon
    let folderIcon = isExpanded ? fallbackIcon : foldedIcon
    let iconColor = Color(hex: config.iconColor)

    Group {
      if config.direction == "below" {
        Button(action: {
          if activation == .click { toggleExpansion($showPopover) }
        }) {
          HStack(spacing: 4) {
            NerdFontIcon(folderIcon).foregroundColor(iconColor)
            if let name = config.name { Text(name).foregroundColor(iconColor) }
          }
        }
        .buttonStyle(WidgetButtonStyle())
        .widgetPopoverActivation(
          $showPopover,
          activation: activation,
          hoverState: hoverState
        )
        .widgetPopup(
          isPresented: $showPopover,
          activation: activation,
          hoverState: hoverState
        ) {
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

          Button(action: { toggleExpansion($isExpandedInline) }) {
            HStack(spacing: 4) {
              NerdFontIcon(folderIcon).foregroundColor(iconColor)
              if let name = config.name { Text(name).foregroundColor(iconColor) }
            }
          }
          .buttonStyle(.plain)

          if config.direction == "right" && isExpanded {
            nestedWidgets()
              .transition(expansionTransition(edge: .leading))
          }
        }
        .environment(\.isInsideWidgetFolder, true)
        .environment(\.kamidanaV1Style, isExpandedInline ? popupStyle ?? v1Style : v1Style)
        .SmoothUIModule()
      }
    }
  }

  @ViewBuilder
  func nestedWidgets(fillWidth: Bool = false) -> some View {
    ForEach(config.widgets, id: \.id) { instance in
      if let factory = WidgetRegistry.shared.factory(for: instance.typeID) {
        if fillWidth {
          factory.makeView(config: instance.config)
            .environment(\.kamidanaV1Style, instance.v1Style)
            .environment(\.kamidanaPopupStyle, instance.v1PopupStyle)
            .environment(\.kamidanaWidgetFormat, instance.v1Format)
            .environment(\.kamidanaWidgetActivation, instance.v1Activate)
            .kamidanaWidgetMotion(instance.v1Motion)
            .environment(\.isInsideWidgetFolder, true)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          factory.makeView(config: instance.config)
            .environment(\.kamidanaV1Style, instance.v1Style)
            .environment(\.kamidanaPopupStyle, instance.v1PopupStyle)
            .environment(\.kamidanaWidgetFormat, instance.v1Format)
            .environment(\.kamidanaWidgetActivation, instance.v1Activate)
            .kamidanaWidgetMotion(instance.v1Motion)
            .environment(\.isInsideWidgetFolder, true)
        }
      }
    }
  }

  private var activation: KamidanaActivation {
    widgetActivation ?? .click
  }

  private func toggleExpansion(_ isExpanded: Binding<Bool>) {
    if motion == .dynamic {
      withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
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
    guard motion == .dynamic else { return .identity }
    return .move(edge: edge).combined(with: .opacity)
  }
}
