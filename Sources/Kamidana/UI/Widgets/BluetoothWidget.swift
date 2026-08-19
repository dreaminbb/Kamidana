import AppKit
import SwiftUI

struct BluetoothWidget: View {
    @EnvironmentObject var bluetooth: BluetoothManager
    @Environment(\.kamidanaV1Style) private var v1Style
    @Environment(\.kamidanaWidgetFormat) private var widgetFormat
    @State private var showPopover = false
    @State private var isButtonHovered = false
    @State private var isPopoverHovered = false

    let config: BluetoothWidgetConfig

    var body: some View {
        let colors = ConfigManager.shared.currentConfig.colors
        Button(action: {
            showPopover.toggle()
            if showPopover {
                bluetooth.refreshPairedDevices()
            }
        }) {
            let statusColor = bluetooth.isBluetoothOn
                ? Color(hex: config.connectedColor) : Color(hex: config.disconnectedColor)
            FormattedWidgetLabel(
                format: widgetFormat ?? "{icon}",
                values: [
                    "icon": bluetooth.isBluetoothOn ? config.iconConnected : config.iconDisconnected,
                    "status": bluetooth.isBluetoothOn ? "on" : "off",
                    "device_count": "\(bluetooth.pairedDevices.count)"
                ],
                iconColor: v1Style?.iconColor.map(Color.init(hex:)) ?? statusColor,
                textColor: v1Style?.color.map(Color.init(hex:)) ?? Color(hex: config.textColor)
            )
        }
        .buttonStyle(WidgetButtonStyle())
        .focusable(false)
        .onHover { hover in
            isButtonHovered = hover
            if hover {
                bluetooth.refreshPairedDevices()
                showPopover = true
            } else {
                checkDismiss()
            }
        }
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {

                if !bluetooth.isBluetoothOn {
                    Text("Bluetooth is Off")
                        .foregroundColor(Color(hex: colors.textTertiary))
                        .frame(width: 250, alignment: .center)
                        .padding()
                } else {
                    if bluetooth.pairedDevices.isEmpty {
                        Text("No paired devices")
                            .foregroundColor(Color(hex: colors.textTertiary))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(bluetooth.pairedDevices) { info in
                                    DeviceRow(info: info, bluetooth: bluetooth)
                                }
                            }
                        }
                        .frame(maxHeight: 260)
                    }
                }

                Divider()
                    .background(Color(hex: colors.surfaceHighlight))

                // Open settings button
                SettingsRowButton() {
                    bluetooth.openBluetoothSettings()
                }
            }
            .padding(12)
            .frame(width: 260)
            .background(Color(hex: colors.background))
            .onHover { hover in
                isPopoverHovered = hover
                if !hover {
                    checkDismiss()
                }
            }
        }
    }

    private func checkDismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if !isButtonHovered && !isPopoverHovered {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showPopover = false
                }
            }
        }
    }
}

struct DeviceRow: View {
    let info: BluetoothDeviceInfo
    @ObservedObject var bluetooth: BluetoothManager
    @State private var isHovered = false

    var body: some View {
        let colors = ConfigManager.shared.currentConfig.colors
        HStack(spacing: 8) {
            NerdFontIcon(info.isConnected ? "" : "")
                .foregroundColor(info.isConnected ? Color(hex: colors.accent) : Color(hex: colors.textTertiary))

            Text(info.name)
                .lineLimit(1)
                .foregroundColor(Color(hex: colors.textPrimary))

            Spacer()

            if info.isConnected {
                Text("Connected")
                    .font(.caption)
                    .foregroundColor(Color(hex: colors.accent))
            } else {
                Text("Saved")
                    .font(.caption)
                    .foregroundColor(Color(hex: colors.textTertiary))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            isHovered
                ? Color(hex: colors.surfaceHighlight).opacity(0.8)
                : (info.isConnected ? Color(hex: colors.surfaceHighlight).opacity(0.4) : Color(hex: colors.surface).opacity(0.3))
        )
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onHover { hover in
            isHovered = hover
        }
        .onTapGesture {
            bluetooth.openBluetoothSettings()
        }
    }
}

struct SettingsRowButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        let colors = ConfigManager.shared.currentConfig.colors
        HStack {
            NerdFontIcon("󰝖")
                .foregroundColor(Color(hex: colors.accent))
            Text("Bluetooth Settings...")
                .font(.subheadline)
                .foregroundColor(Color(hex: colors.textPrimary))
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isHovered ? Color(hex: colors.surfaceHighlight).opacity(0.8) : Color(hex: colors.surface).opacity(0.5))
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onHover { hover in
            isHovered = hover
        }
        .onTapGesture {
            action()
        }
    }
}
