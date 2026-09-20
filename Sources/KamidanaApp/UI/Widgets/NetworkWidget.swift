import SwiftUI

struct NetworkWidget: View {
    static let defaultFormat =
        "{connection_icon} {network_name} {upload} {upload_icon} {download} {download_icon}"

    @EnvironmentObject var matrix: SystemMatrix
    @EnvironmentObject var netManager: NetworkManager
    @Environment(\.theme) private var theme
    @Environment(\.kamidanaWidgetFormat) private var widgetFormat
    @Environment(\.kamidanaWidgetActivation) private var widgetActivation
    @StateObject private var interaction = WidgetInteractionController()

    let config: NetworkWidgetConfig

    var body: some View {
        let colors = ConfigManager.shared.currentConfig.colors
        let upload = matrix.data.internetUsage.map { formatBytes($0.uploadBytesPerSecond) } ?? "--"
        let download =
            matrix.data.internetUsage.map { formatBytes($0.downloadBytesPerSecond) } ?? "--"

        WidgetActionButton(action: { interaction.activate(activation) }) {
            FormattedWidgetLabel(
                format: widgetFormat
                    ?? Self.defaultFormat,
                values: [
                    "connection_icon": connectionIcon,
                    "ssid": netManager.currentSSID,
                    "network_name": netManager.networkDisplayName,
                    "upload": upload,
                    "upload_icon": config.uploadIcon,
                    "download": download,
                    "download_icon": config.downloadIcon,
                ],
                iconColor: theme?.iconForeground ?? Color(hex: config.iconColor),
                textColor: theme?.foreground ?? Color(hex: config.textColor)
            )
            .font(.system(size: 14, weight: .semibold, design: .monospaced))
        }
        .widgetInteraction(controller: interaction, activation: activation) { presentation in
            popoverContent(
                colors: colors,
                upload: upload,
                download: download,
                isPresented: presentation
            )
                .onAppear { netManager.refreshNetworkDetails(forcePublicIP: false) }
        }
    }

    @ViewBuilder
    private func popoverContent(
        colors: GlobalColorsConfig,
        upload: String,
        download: String,
        isPresented: Binding<Bool>
    )
        -> some View
    {
        let showsWiFiConnectionControls = netManager.currentConnection != "LAN"

        Group {
            if showsWiFiConnectionControls {
                HStack(alignment: .top, spacing: 16) {
                    networkInformationPanel(colors: colors, upload: upload, download: download)
                        .frame(width: 300, alignment: .leading)

                    Divider()

                    WiFiConnectionView(
                        config: config,
                        isPresented: isPresented,
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
    }

    @ViewBuilder
    private func networkInformationPanel(
        colors: GlobalColorsConfig,
        upload: String,
        download: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(netManager.networkDisplayName)
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
    private func detailRow(label: String, value: NetworkValueState, colors: GlobalColorsConfig)
        -> some View
    {
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

    private var activation: KamidanaActivation { widgetActivation ?? .click }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .binary
        if bytes == 0 { return "0 KB" }
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
