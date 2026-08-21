import SwiftUI

struct LocalSendWidget: View {
    @ObservedObject var localSend: LocalSendManager
    var body: some View {
        let colors = ConfigManager.shared.currentConfig.colors
        if !localSend.discoveredDevices.isEmpty {
            HStack(spacing: 4) {
                NerdFontIcon("󰈆")
                    .foregroundColor(Color(hex: colors.primary))
                Text("\(localSend.discoveredDevices.count) Devices")
                    .foregroundColor(Color(hex: colors.textPrimary))
            }
            .SmoothUIModule()
        }
    }
}
