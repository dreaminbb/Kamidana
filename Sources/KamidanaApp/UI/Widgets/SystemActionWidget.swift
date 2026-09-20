import SwiftUI

struct SystemActionWidget: View {
    @Environment(\.theme) private var theme
    let systemController = SystemController()
    let config: SystemActionWidgetConfig
    
    var body: some View {
        WidgetActionButton(action: performAction) {
            HStack(spacing: 8) {
                NerdFontIcon(config.icon)
                    .foregroundColor(Color(hex: config.iconColor))
                    .frame(width: 20, alignment: .center)
                
                if let name = config.name, !name.isEmpty {
                    let colors = ConfigManager.shared.currentConfig.colors
                    Text(name)
                        .foregroundColor(theme?.foreground ?? Color(hex: colors.textPrimary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
    }
    
    private func performAction() {
        switch config.action {
        case "aboutThisMac":
            systemController.showAboutThisMac()
        case "sleep":
            systemController.sleepSystem()
        case "shutdown":
            systemController.shutdownSystem()
        case "reboot":
            systemController.rebootSystem()
        case "logout":
            systemController.logoutSystem()
        case "lockScreen":
            systemController.lockScreen()
        default:
            break
        }
    }
}
