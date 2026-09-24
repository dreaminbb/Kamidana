import SwiftUI

public struct CaffeinateWidgetConfig: Codable, Hashable {
    public var format: String
    public var iconActive: String?
    public var iconInactive: String?

    public init(
        format: String = "{icon}",
        iconActive: String? = nil,
        iconInactive: String? = nil
    ) {
        self.format = format
        self.iconActive = iconActive
        self.iconInactive = iconInactive
    }
}

struct CaffeinateWidget: View {
    @Environment(\.theme) private var theme
    @ObservedObject private var manager = CaffeinateManager.shared
    let config: CaffeinateWidgetConfig

    var body: some View {
        WidgetActionButton(action: {
            manager.toggle()
        }) {
            HStack(spacing: 8) {
                NerdFontIcon(manager.isActive ? (config.iconActive ?? "󰅶") : (config.iconInactive ?? "󰾆"), size: 16)
                    .foregroundColor(manager.isActive ? theme?.severityColors.warning : theme?.foreground)
                
                let text = config.format.replacingOccurrences(of: "{icon}", with: "")
                if !text.isEmpty {
                    Text(text.trimmingCharacters(in: .whitespaces))
                        .foregroundColor(theme?.foreground)
                }
            }
        }
    }
}
