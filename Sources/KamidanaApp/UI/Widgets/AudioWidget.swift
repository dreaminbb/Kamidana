import SwiftUI

struct AudioWidget: View {
    @EnvironmentObject private var audioVM: AudioViewModel
    @Environment(\.kamidanaV1Style) private var v1Style
    @Environment(\.kamidanaWidgetFormat) private var widgetFormat
    @Environment(\.kamidanaWidgetActivation) private var widgetActivation

    let config: AudioWidgetConfig

    @State private var showPopover = false
    @State private var hoverState = WidgetPopoverHoverState()

    var body: some View {
        let colors = ConfigManager.shared.currentConfig.colors

        Button(action: { if activation == .click { showPopover.toggle() } }) {
            FormattedWidgetLabel(
                format: widgetFormat ?? "{icon} {volume}%",
                values: compactValues,
                iconColor: Color(hex: compactIconColor),
                textColor: Color(hex: v1Style?.color ?? colors.textPrimary)
            )
        }
        .buttonStyle(WidgetButtonStyle())
        .widgetPopoverActivation($showPopover, activation: activation, hoverState: hoverState)
        .widgetPopup(
            isPresented: $showPopover,
            activation: activation,
            hoverState: hoverState
        ) {
            popoverContent(colors: colors)
        }
    }

    @ViewBuilder
    private func popoverContent(colors: GlobalColorsConfig) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Audio")
                .font(.headline)
                .foregroundColor(Color(hex: colors.textPrimary))

            if config.showsOutputManagement {
                audioSection(
                    title: "Output",
                    format: audioVM.outputFormat,
                    devices: audioVM.outputDevices,
                    currentDeviceID: audioVM.currentOutputDevice?.id,
                    volume: Binding(
                        get: { audioVM.outputVolume },
                        set: { audioVM.setOutputVolume($0) }
                    ),
                    isMuted: audioVM.isOutputMuted,
                    activeIcon: config.speakerIcon,
                    mutedIcon: config.speakerMutedIcon,
                    activeColor: config.activeColor,
                    toggleMute: audioVM.toggleOutputMute,
                    selectDevice: audioVM.changeOutputDevice,
                    colors: colors
                )
            }

            if config.showsOutputManagement && config.showsInputManagement {
                Divider().overlay(Color(hex: colors.surfaceBorder))
            }

            if config.showsInputManagement {
                audioSection(
                    title: "Input",
                    format: audioVM.inputFormat,
                    devices: audioVM.inputDevices,
                    currentDeviceID: audioVM.currentInputDevice?.id,
                    volume: Binding(
                        get: { audioVM.inputVolume },
                        set: { audioVM.setInputVolume($0) }
                    ),
                    isMuted: audioVM.isInputMuted,
                    activeIcon: config.micIcon,
                    mutedIcon: config.micMutedIcon,
                    activeColor: config.micActiveColor,
                    toggleMute: audioVM.toggleInputMute,
                    selectDevice: audioVM.changeInputDevice,
                    colors: colors
                )
            }

            if !config.showsOutputManagement && !config.showsInputManagement {
                Text("Input and output controls are disabled.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: colors.textTertiary))
            }
        }
        .padding()
        .frame(width: 340, alignment: .leading)
    }

    @ViewBuilder
    private func audioSection(
        title: String,
        format: String,
        devices: [AudioDevice],
        currentDeviceID: AudioDevice.ID?,
        volume: Binding<Float>,
        isMuted: Bool,
        activeIcon: String,
        mutedIcon: String,
        activeColor: String,
        toggleMute: @escaping () -> Void,
        selectDevice: @escaping (AudioDevice) -> Void,
        colors: GlobalColorsConfig
    ) -> some View {
        let rowHeight: CGFloat = 30
        let listHeight = devices.count >= 4
            ? 120
            : max(rowHeight, CGFloat(devices.count) * rowHeight + CGFloat(max(0, devices.count - 1)) * 6)

        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color(hex: colors.textSecondary))
                Spacer()
                Text(format.isEmpty ? "Unknown" : format)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(hex: colors.textTertiary))
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                Button(action: toggleMute) {
                    NerdFontIcon(isMuted ? mutedIcon : activeIcon, size: 13)
                        .foregroundColor(Color(hex: isMuted ? config.mutedColor : activeColor))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Slider(value: volume, in: 0...1)
                    .tint(Color(hex: activeColor))

                Text(String(format: "%.0f%%", volume.wrappedValue * 100))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(hex: colors.textPrimary))
                    .frame(width: 36, alignment: .trailing)
            }

            if devices.isEmpty {
                Text("No devices available.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: colors.textTertiary))
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 6) {
                        ForEach(devices) { device in
                            Button(action: { selectDevice(device) }) {
                                HStack(spacing: 8) {
                                    NerdFontIcon(currentDeviceID == device.id ? "" : "", size: 10)
                                        .foregroundColor(
                                            Color(
                                                hex: currentDeviceID == device.id
                                                    ? activeColor : colors.textTertiary
                                            )
                                        )
                                    Text(device.name)
                                        .foregroundColor(Color(hex: colors.textPrimary))
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 5)
                                .padding(.horizontal, 8)
                                .frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .leading)
                                .background(Color(hex: colors.surface))
                                .cornerRadius(6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                // Show up to three devices at their natural size. Four or more devices
                // use this fixed viewport and scroll inside it instead of shrinking
                // every row to fit the popup.
                .frame(height: listHeight)
            }
        }
    }

    private var compactValues: [String: String] {
        let usesOutput = config.showsOutputManagement
        let icon =
            usesOutput
            ? (audioVM.isOutputMuted ? config.speakerMutedIcon : config.speakerIcon)
            : (audioVM.isInputMuted ? config.micMutedIcon : config.micIcon)
        let volume = usesOutput ? audioVM.outputVolume : audioVM.inputVolume

        return [
            "icon": icon,
            "volume": String(format: "%.0f", volume * 100),
            "output_icon": audioVM.isOutputMuted ? config.speakerMutedIcon : config.speakerIcon,
            "output_volume": String(format: "%.0f", audioVM.outputVolume * 100),
            "output_device": audioVM.currentOutputDevice?.name ?? "Unknown",
            "input_icon": audioVM.isInputMuted ? config.micMutedIcon : config.micIcon,
            "input_volume": String(format: "%.0f", audioVM.inputVolume * 100),
            "input_device": audioVM.currentInputDevice?.name ?? "Unknown",
        ]
    }

    private var compactIconColor: String {
        if let color = v1Style?.iconColor { return color }
        if config.showsOutputManagement {
            return audioVM.isOutputMuted ? config.mutedColor : config.activeColor
        }
        return audioVM.isInputMuted ? config.mutedColor : config.micActiveColor
    }

    private var activation: KamidanaActivation { widgetActivation ?? .hover }
}
