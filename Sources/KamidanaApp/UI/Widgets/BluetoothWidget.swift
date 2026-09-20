import AppKit
import SwiftUI

struct BluetoothWidget: View {
    @EnvironmentObject var bluetooth: BluetoothManager
    @Environment(\.theme) private var theme
    @Environment(\.kamidanaWidgetFormat) private var widgetFormat
    @Environment(\.kamidanaWidgetActivation) private var widgetActivation
    @StateObject private var interaction = WidgetInteractionController()

    let config: BluetoothWidgetConfig

    var body: some View {
        let colors = ConfigManager.shared.currentConfig.colors
        WidgetActionButton(action: {
            if interaction.activate(activation) {
                bluetooth.refreshPairedDevices()
            }
        }) {
            let statusColor =
                bluetooth.isBluetoothOn
                ? Color(hex: config.connectedColor) : Color(hex: config.disconnectedColor)
            let deviceValues = Self.connectedDeviceFormatValues(bluetooth.pairedDevices)
            FormattedWidgetLabel(
                format: widgetFormat ?? "{icon}",
                values: [
                    "icon": bluetooth.isBluetoothOn
                        ? config.iconConnected : config.iconDisconnected,
                    "status": bluetooth.isBluetoothOn ? "on" : "off",
                    "device_count": deviceValues.deviceCount,
                    "device": deviceValues.deviceCount,
                    "device_name": deviceValues.deviceName,
                ],
                iconColor: theme?.iconForeground ?? statusColor,
                textColor: theme?.foreground ?? Color(hex: config.textColor)
            )
        }
        .focusable(false)
        .onHover { hover in
            if hover {
                bluetooth.refreshPairedDevices()
            }
        }
        .widgetInteraction(controller: interaction, activation: activation) { _ in
            let connectedDevices = Self.connectedDevices(bluetooth.pairedDevices)
            VStack(alignment: .leading, spacing: 10) {

                if !bluetooth.isBluetoothOn {
                    Text("Bluetooth is Off")
                        .foregroundColor(Color(hex: colors.textTertiary))
                        .frame(width: 250, alignment: .center)
                        .padding()
                } else {
                    if connectedDevices.isEmpty {
                        Text("No connected devices")
                            .foregroundColor(Color(hex: colors.textTertiary))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(connectedDevices) { info in
                                    DeviceRow(info: info, bluetooth: bluetooth)
                                }
                            }
                        }
                        .frame(height: Self.deviceListHeight(for: connectedDevices.count))
                    }
                }
            }
            .padding(12)
            .frame(width: 320)
        }
    }

    private var activation: KamidanaActivation { widgetActivation ?? .click }

    static func connectedDeviceFormatValues(
        _ devices: [BluetoothDeviceInfo]
    ) -> (deviceCount: String, deviceName: String) {
        let connectedDevices = Self.connectedDevices(devices)
        return (
            deviceCount: "\(connectedDevices.count)",
            deviceName: connectedDevices.first?.name ?? ""
        )
    }

    static func connectedDevices(_ devices: [BluetoothDeviceInfo]) -> [BluetoothDeviceInfo] {
        devices.filter(\.isConnected)
    }

    static func deviceListHeight(for deviceCount: Int) -> CGFloat {
        let rowHeight: CGFloat = 112
        let rowSpacing: CGFloat = 6
        let contentHeight =
            CGFloat(deviceCount) * rowHeight + CGFloat(max(0, deviceCount - 1)) * rowSpacing
        return min(max(contentHeight, rowHeight), 260)
    }
}

struct DeviceRow: View {
    let info: BluetoothDeviceInfo
    @ObservedObject var bluetooth: BluetoothManager
    @State private var isHovered = false

    var body: some View {
        let colors = ConfigManager.shared.currentConfig.colors
        WidgetActionButton(action: { _ = bluetooth.openBluetoothSettings() }) {
            VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                NerdFontIcon(info.isConnected ? "󰂱" : "󰂯", size: 16)
                    .foregroundColor(
                        info.isConnected
                            ? Color(hex: colors.accent) : Color(hex: colors.textTertiary))

                Text(info.name)
                    .lineLimit(1)
                    .foregroundColor(Color(hex: colors.textPrimary))

                Spacer(minLength: 4)

                Text(info.isConnected ? "Connected" : "Saved")
                    .font(.caption)
                    .foregroundColor(
                        info.isConnected
                            ? Color(hex: colors.accent) : Color(hex: colors.textTertiary))
            }

            Divider()
                .overlay(Color(hex: colors.surfaceBorder))

            VStack(alignment: .leading, spacing: 4) {
                detailRow(label: "Address", value: info.id, colors: colors)
                detailRow(
                    label: "Connection",
                    value: info.isConnected ? "Connected" : "Not connected",
                    colors: colors
                )
                detailRow(
                    label: "Pairing",
                    value: info.isPaired ? "Paired" : "Not paired",
                    colors: colors
                )
            }
            .font(.system(size: 11, design: .monospaced))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                isHovered
                    ? Color(hex: colors.surfaceHighlight).opacity(0.8)
                    : (info.isConnected
                        ? Color(hex: colors.surfaceHighlight).opacity(0.4)
                        : Color(hex: colors.surface).opacity(0.3))
            )
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .onHover { hover in
            isHovered = hover
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    private func detailRow(label: String, value: String, colors: GlobalColorsConfig) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .foregroundColor(Color(hex: colors.textSecondary))
                .frame(width: 76, alignment: .leading)
            Text(value)
                .foregroundColor(Color(hex: colors.textPrimary))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}
