import SwiftUI

struct NetworkWidget: View {
    @EnvironmentObject var matrix: SystemMatrix
    @Environment(\.kamidanaV1Style) private var v1Style
    @Environment(\.kamidanaWidgetFormat) private var widgetFormat
    @State private var showPopover = false
    @State private var isHovered = false

    let config: NetworkWidgetConfig

    var body: some View {
        let colors = ConfigManager.shared.currentConfig.colors
        if let net = matrix.data.internetUsage {
            Button(action: { showPopover.toggle() }) {
                FormattedWidgetLabel(
                    format: widgetFormat ?? "󰔝 {upload}/s 󰓅 {download}/s",
                    values: [
                        "upload": formatBytes(net.uploadBytesPerSecond),
                        "download": formatBytes(net.downloadBytesPerSecond)
                    ],
                    iconColor: v1Style?.iconColor.map(Color.init(hex:)) ?? Color(hex: config.iconColor),
                    textColor: v1Style?.color.map(Color.init(hex:)) ?? Color(hex: config.textColor),
                    iconSize: 12
                )
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
            }
            .buttonStyle(.plain)
            .SmoothUIModule()
            .onHover { hover in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { isHovered = hover }
                showPopover = hover
            }
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Network Activity")
                        .font(.headline)
                        .foregroundColor(Color(hex: colors.textPrimary))
                        .padding(.bottom, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            NerdFontIcon("󰲝").foregroundColor(Color(hex: colors.primary)).frame(
                                width: 20)
                            Text("Upload:").foregroundColor(Color(hex: colors.textSecondary)).frame(
                                width: 70, alignment: .leading)
                            Text("\(formatBytes(net.uploadBytesPerSecond))/s").foregroundColor(
                                Color(hex: colors.info))
                        }
                        HStack {
                            Image(systemName: "").frame(width: 20)
                            Text("Download:").foregroundColor(Color(hex: colors.textSecondary)).frame(
                                width: 70, alignment: .leading)
                            Text("\(formatBytes(net.downloadBytesPerSecond))/s").foregroundColor(
                                Color(hex: colors.info))
                        }
                        .font(.system(size: 11, design: .monospaced))
                    }
                }
                .padding()
                .frame(width: 220)
                .background(Color(hex: colors.background))
            }
        }
    }

    // Helper function to format byte counts cleanly
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .binary
        if bytes == 0 { return "0 KB" }
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
