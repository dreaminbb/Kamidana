import AppKit
import SwiftUI

struct BluetoothWidget: View {
    @ObservedObject var bluetooth: BluetoothManager
    var theme: Theme

    @State private var showPopover = false
    @State private var isButtonHovered = false
    @State private var isPopoverHovered = false

    var body: some View {
        Button(action: {
            showPopover.toggle()
            if showPopover {
                bluetooth.refreshPairedDevices()
            }
        }) {
            HStack(spacing: 4) {
                NerdFontIcon(bluetooth.isBluetoothOn ? .bluetooth : .bluetoothSlash)
                    .foregroundColor(bluetooth.isBluetoothOn ? theme.accent : theme.textTertiary)
            }
        }
        .buttonStyle(.plain)
        .focusable(false)
        .SmoothUIModule(theme: theme)
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
                        .foregroundColor(theme.textTertiary)
                        .frame(width: 250, alignment: .center)
                        .padding()
                } else {
                    if bluetooth.pairedDevices.isEmpty {
                        Text("No paired devices")
                            .foregroundColor(theme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(bluetooth.pairedDevices) { info in
                                    DeviceRow(info: info, theme: theme, bluetooth: bluetooth)
                                }
                            }
                        }
                        .frame(maxHeight: 260)
                    }
                }

                Divider()
                    .background(theme.surfaceHighlight)

                // Open settings button
                SettingsRowButton(theme: theme) {
                    bluetooth.openBluetoothSettings()
                }
            }
            .padding(12)
            .frame(width: 260)
            .background(theme.background)
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
    let theme: Theme
    @ObservedObject var bluetooth: BluetoothManager
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            NerdFontIcon(info.isConnected ? .link : .linkPlus)
                .foregroundColor(info.isConnected ? theme.accent : theme.textTertiary)

            Text(info.name)
                .lineLimit(1)
                .foregroundColor(theme.textPrimary)

            Spacer()

            if info.isConnected {
                Text("Connected")
                    .font(.caption)
                    .foregroundColor(theme.accent)
            } else {
                Text("Saved")
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            isHovered
                ? theme.surfaceHighlight.opacity(0.8)
                : (info.isConnected ? theme.surfaceHighlight.opacity(0.4) : theme.surface.opacity(0.3))
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
    let theme: Theme
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack {
            NerdFontIcon(.list)
                .foregroundColor(theme.accent)
            Text("Bluetooth Settings...")
                .font(.subheadline)
                .foregroundColor(theme.textPrimary)
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isHovered ? theme.surfaceHighlight.opacity(0.8) : theme.surface.opacity(0.5))
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
