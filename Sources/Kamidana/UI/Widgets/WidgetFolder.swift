import SwiftUI

struct WidgetFolder: View {
  let config: WidgetFolderConfig

  @State private var isExpandedInline: Bool = true
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
        .buttonStyle(.plain)
        .SmoothUIModule()
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
          VStack(alignment: .leading, spacing: 8) {
            if let name = config.name {
              Text(name)
                .font(.headline)
                .foregroundColor(Color(hex: ConfigManager.shared.currentConfig.colors.textPrimary))
            }
            nestedWidgets()
              .focusable(false)
          }
          .padding()
          .background(Color(hex: ConfigManager.shared.currentConfig.colors.background))
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
          .SmoothUIModule()

          if config.direction == "right" && isExpanded {
            nestedWidgets()
          }
        }
      }
    }
  }

  @ViewBuilder
  func nestedWidgets() -> some View {
    ForEach(config.widgets, id: \.id) { instance in
      if let factory = WidgetRegistry.shared.factory(for: instance.typeID) {
          factory.makeView(config: instance.config)
      }
    }
  }
}
