import SwiftUI

struct NetworkWidget: View {
    static let defaultFormat = "{connection_icon} {ssid} {upload} {upload_icon} {download} {download_icon}"

    @EnvironmentObject var matrix: SystemMatrix
    @EnvironmentObject var netManager: NetworkManager
    @Environment(\.kamidanaV1Style) private var v1Style
    @Environment(\.kamidanaWidgetFormat) private var widgetFormat
    @Environment(\.kamidanaWidgetActivation) private var widgetActivation
    @State private var showPopover = false
    @State private var hoverState = WidgetPopoverHoverState()

    let config: NetworkWidgetConfig

    var body: some View {
        let colors = ConfigManager.shared.currentConfig.colors
        let upload = matrix.data.internetUsage.map { formatBytes($0.uploadBytesPerSecond) } ?? "--"
        let download = matrix.data.internetUsage.map { formatBytes($0.downloadBytesPerSecond) } ?? "--"

        Button(action: { if activation == .click { showPopover.toggle() } }) {
            FormattedWidgetLabel(
                format: widgetFormat
                    ?? Self.defaultFormat,
                values: [
                    "connection_icon": connectionIcon,
                    "ssid": netManager.currentSSID,
                    "upload": upload,
                    "upload_icon": config.uploadIcon,
                    "download": download,
                    "download_icon": config.downloadIcon,
                ],
                iconColor: v1Style?.iconColor.map(Color.init(hex:)) ?? Color(hex: config.iconColor),
                textColor: v1Style?.color.map(Color.init(hex:)) ?? Color(hex: config.textColor)
            )
            .font(.system(size: 14, weight: .semibold, design: .monospaced))
        }
        .buttonStyle(WidgetButtonStyle())
        .widgetPopoverActivation($showPopover, activation: activation, hoverState: hoverState)
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            popoverContent(colors: colors, upload: upload, download: download)
                .onAppear { netManager.refreshNetworkDetails(forcePublicIP: false) }
                .onHover {
                    hoverState.updatePopoverHover($0, isPresented: $showPopover, activation: activation)
                }
        }
    }

    @ViewBuilder
    private func popoverContent(colors: GlobalColorsConfig, upload: String, download: String) -> some View {
        let showsWiFiConnectionControls = netManager.currentConnection != "LAN"

        Group {
            if showsWiFiConnectionControls {
                HStack(alignment: .top, spacing: 16) {
                    networkInformationPanel(colors: colors, upload: upload, download: download)
                        .frame(width: 300, alignment: .leading)

                    Divider()

                    WiFiConnectionView(
                        config: config,
                        isPresented: $showPopover,
                        showsSurface: false
                    )
                    .environmentObject(netManager)
                    .frame(width: 280, alignment: .leading)
                }
            } else {
                networkInformationPanel(colors: colors, upload: upload, download: download)
                    .frame(width: 340, alignment: .leading)
            }
        }
        .padding()
        .background(Color(hex: colors.background))
    }

    @ViewBuilder
    private func networkInformationPanel(
        colors: GlobalColorsConfig,
        upload: String,
        download: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network")
                .font(.headline)
                .foregroundColor(Color(hex: colors.textPrimary))

            VStack(alignment: .leading, spacing: 8) {
                detailRow(
                    label: "Network",
                    value: .available(netManager.networkDisplayName),
                    colors: colors
                )
                detailRow(
                    label: "Connection",
                    value: .available(connectionDescription),
                    colors: colors
                )
                detailRow(
                    label: "Interface",
                    value: netManager.activeInterfaceName.map(NetworkValueState.available)
                        ?? .unavailable("Not available"),
                    colors: colors
                )
                detailRow(label: "Local IP", value: netManager.localIPv4State, colors: colors)
                detailRow(label: "DNS", value: netManager.dnsServersState, colors: colors)
                detailRow(label: "Public IP", value: netManager.publicIPState, colors: colors)
                detailRow(label: "Upload", value: .available("\(upload)/s"), colors: colors)
                detailRow(label: "Download", value: .available("\(download)/s"), colors: colors)
            }
        }
    }

    @ViewBuilder
    private func detailRow(label: String, value: NetworkValueState, colors: GlobalColorsConfig) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundColor(Color(hex: colors.textSecondary))
                .frame(width: 82, alignment: .leading)
            switch value {
            case .loading:
                detailValue("Loading...", color: colors.textTertiary)
            case .available(let text):
                detailValue(text, color: colors.info)
            case .unavailable(let reason):
                detailValue(reason, color: colors.textTertiary)
            }
        }
        .font(.system(size: 13, design: .monospaced))
    }

    private func detailValue(_ value: String, color: String) -> some View {
        Text(value)
            .foregroundColor(Color(hex: color))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var connectionDescription: String {
        switch netManager.currentConnection {
        case "LAN": return "Wired Ethernet"
        case "WIFI": return "Wi-Fi"
        case "OTHER": return "Other"
        default: return "Offline"
        }
    }

    private var connectionIcon: String {
        switch netManager.currentConnection {
        case "LAN": return config.wiredIcon
        case "WIFI": return config.wirelessIcon
        default: return config.offlineIcon
        }
    }

    private var activation: KamidanaActivation { widgetActivation ?? .hover }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .binary
        if bytes == 0 { return "0 KB" }
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
