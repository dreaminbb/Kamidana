import SwiftUI

struct WidgetFolder: View {
  let config: WidgetFolderConfig
  private let verticalContentWidth: CGFloat = 220
  private let statusBarHeight: CGFloat = 40

  @State private var isExpandedInline: Bool = false
  @State private var showPopover = false

  var body: some View {
    let isExpanded = config.direction == "below" ? showPopover : isExpandedInline
    let fallbackIcon = config.icon ?? "󰉋"
    let foldedIcon = config.iconFolded ?? fallbackIcon
    let folderIcon = isExpanded ? fallbackIcon : foldedIcon
    let iconColor = Color(hex: config.iconColor)

    Group {
      if config.direction == "below" {
        Button(action: { showPopover.toggle() }) {
          HStack(spacing: 4) {
            NerdFontIcon(folderIcon).foregroundColor(iconColor)
            if let name = config.name { Text(name).foregroundColor(iconColor) }
          }
        }
        .buttonStyle(WidgetButtonStyle())
        .overlay(alignment: .topLeading) {
          if showPopover {
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
            .background(Color(hex: ConfigManager.shared.currentConfig.colors.background))
            .overlay(
              Rectangle()
                .stroke(
                  Color(hex: ConfigManager.shared.currentConfig.colors.surfaceBorder),
                  lineWidth: 1
                )
            )
            .contentShape(Rectangle())
            .offset(y: statusBarHeight)
          }
        }
      } else {
        HStack(spacing: 8) {
          if config.direction == "left" && isExpanded {
            nestedWidgets()
          }

          Button(action: {
            withAnimation { isExpandedInline.toggle() }
          }) {
            HStack(spacing: 4) {
              NerdFontIcon(folderIcon).foregroundColor(iconColor)
              if let name = config.name { Text(name).foregroundColor(iconColor) }
            }
          }
          .buttonStyle(.plain)

          if config.direction == "right" && isExpanded {
            nestedWidgets()
          }
        }
        .environment(\.isInsideWidgetFolder, true)
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
            .environment(\.kamidanaWidgetFormat, instance.v1Format)
            .environment(\.isInsideWidgetFolder, true)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          factory.makeView(config: instance.config)
            .environment(\.kamidanaV1Style, instance.v1Style)
            .environment(\.kamidanaWidgetFormat, instance.v1Format)
            .environment(\.isInsideWidgetFolder, true)
        }
      }
    }
  }
}
