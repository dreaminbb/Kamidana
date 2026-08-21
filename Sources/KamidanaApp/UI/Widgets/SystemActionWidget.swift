import SwiftUI

struct SystemActionWidget: View {
    @Environment(\.kamidanaV1Style) private var v1Style
    let systemController = SystemController()
    let config: SystemActionWidgetConfig
    
    var body: some View {
        Button(action: {
            performAction()
        }) {
            HStack(spacing: 8) {
                NerdFontIcon(config.icon)
                    .foregroundColor(Color(hex: config.iconColor))
                    .frame(width: 20, alignment: .center)
                
                if let name = config.name, !name.isEmpty {
                    let colors = ConfigManager.shared.currentConfig.colors
                    Text(name)
                        .foregroundColor(Color(hex: v1Style?.color ?? colors.textPrimary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(WidgetButtonStyle())
    }
    
    private func performAction() {
        switch config.action {
        case "aboutThisMac":
            let _ = systemController.showAboutThisMac()
        case "sleep":
            let _ = systemController.sleepSystem()
        case "shutdown":
            let _ = systemController.shutdownSystem()
        case "reboot":
            let _ = systemController.rebootSystem()
        case "logout":
            let _ = systemController.logoutSystem()
        case "lockScreen":
            let _ = systemController.lockScreen()
        default:
            break
        }
    }
}
