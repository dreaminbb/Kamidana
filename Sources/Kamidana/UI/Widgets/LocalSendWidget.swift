import SwiftUI

struct LocalSendWidget: View {
    @ObservedObject var localSend: LocalSendManager
    var theme: Theme

    var body: some View {
        if !localSend.discoveredDevices.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "paperplane.circle.fill")
                    .foregroundColor(theme.blue)
                Text("\(localSend.discoveredDevices.count) Devices")
                    .foregroundColor(theme.text)
            }
            .SmoothUIModule(theme: theme)
        }
    }
}
