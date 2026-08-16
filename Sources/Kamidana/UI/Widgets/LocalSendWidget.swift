import SwiftUI

struct LocalSendWidget: View {
    @ObservedObject var localSend: LocalSendManager
    var theme: Theme

    var body: some View {
        if !localSend.discoveredDevices.isEmpty {
            HStack(spacing: 4) {
                NerdFontIcon("󰈆")
                    .foregroundColor(theme.primary)
                Text("\(localSend.discoveredDevices.count) Devices")
                    .foregroundColor(theme.textPrimary)
            }
            .SmoothUIModule(theme: theme)
        }
    }
}
