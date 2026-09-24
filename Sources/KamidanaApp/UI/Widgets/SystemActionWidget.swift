import SwiftUI

struct SystemActionWidget: View {
    @Environment(\.theme) private var theme
    @ObservedObject private var forceQuitManager = ForceQuitManager.shared
    let systemController = SystemController()
    let config: SystemActionWidgetConfig

    private var isForceQuit: Bool { config.action == "forceQuit" }
    
    var body: some View {
        WidgetActionButton(action: performAction) {
            HStack(spacing: 8) {
                NerdFontIcon(config.icon, size: 20)
                    .foregroundColor(theme?.iconForeground ?? Color(hex: config.iconColor))
                
                VStack(alignment: .leading, spacing: 4) {
                    if let name = config.name, !name.isEmpty {
                        let colors = ConfigManager.shared.currentConfig.colors
                        Text(name)
                            .foregroundColor(theme?.foreground ?? Color(hex: colors.textPrimary))
                    }
                    if isForceQuit {
                        Text(forceQuitManager.statusMessage)
                            .font(.caption)
                            .foregroundColor(
                                forceQuitManager.feedback?.isFailure == true
                                    ? theme?.severityColors.critical ?? .primary
                                    : theme?.foreground ?? .secondary
                            )
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .disabled(isForceQuit && !forceQuitManager.canForceQuit)
        .onAppear {
            if isForceQuit { forceQuitManager.startMonitoring() }
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
        case "forceQuit":
            Task { await forceQuitManager.forceQuitCurrentApplication() }
        default:
            break
        }
    }
}
