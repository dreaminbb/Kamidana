import SwiftUI

struct AudioWidget: View {
    @EnvironmentObject var audioVM: AudioViewModel
    @Environment(\.kamidanaV1Style) private var v1Style
    @Environment(\.kamidanaWidgetFormat) private var widgetFormat
    let config: AudioWidgetConfig
    
    @State private var showAudioPopover = false
    @State private var showMicPopover = false
    @State private var isHovered = false

    var body: some View {
        let colors = ConfigManager.shared.currentConfig.colors
        HStack(spacing: 12) {
            // Output (Speaker)
            HStack(spacing: 6) {
                Button(action: { showAudioPopover.toggle() }) {
                    FormattedWidgetLabel(
                        format: widgetFormat ?? "{icon} {volume}%",
                        values: [
                            "icon": audioVM.isOutputMuted
                                ? config.speakerMutedIcon : config.speakerIcon,
                            "volume": String(format: "%.0f", audioVM.outputVolume * 100),
                            "device": audioVM.outputFormat
                        ],
                        iconColor: Color(
                            hex: v1Style?.iconColor
                                ?? (audioVM.isOutputMuted ? config.mutedColor : config.activeColor)),
                        textColor: Color(hex: v1Style?.color ?? colors.textPrimary)
                    )
                    .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showAudioPopover, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Output Devices")
                            .font(.headline)
                            .foregroundColor(Color(hex: colors.textPrimary))
                            .padding(.bottom, 5)

                        HStack {
                            Button(action: { audioVM.toggleOutputMute() }) {
                                NerdFontIcon(
                                    audioVM.isOutputMuted
                                        ? config.speakerMutedIcon : config.speakerIcon,
                                    size: 10
                                )
                                .foregroundColor(Color(hex: colors.textTertiary))
                            }
                            .buttonStyle(.plain)
                            Slider(
                                value: Binding(
                                    get: { audioVM.outputVolume },
                                    set: { audioVM.setOutputVolume($0) }), in: 0.0...1.0
                            )
                            .frame(width: 150).accentColor(Color(hex: config.activeColor))
                            NerdFontIcon(config.speakerIcon, size: 10).foregroundColor(
                                Color(hex: colors.textTertiary)
                            )
                        }
                        .padding(.bottom, 5)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(audioVM.outputDevices) { device in
                                    Button(action: { audioVM.changeOutputDevice(device) }) {
                                        HStack {
                                            Image(
                                                systemName: audioVM.currentOutputDevice?.id
                                                    == device.id
                                                    ? "checkmark.circle.fill" : "circle"
                                            )
                                            .foregroundColor(
                                                audioVM.currentOutputDevice?.id == device.id
                                                    ? Color(hex: config.activeColor) : Color(hex: colors.textTertiary))
                                            Text(device.name).foregroundColor(Color(hex: colors.textPrimary))
                                            Spacer()
                                        }
                                        .frame(width: 200).padding(.vertical, 4).padding(
                                            .horizontal, 8
                                        )
                                        .background(Color(hex: colors.surface)).cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxHeight: 250)
                    }
                    .padding()
                    .background(Color(hex: colors.background))
                }
            }

            // Input (Microphone)
            HStack(spacing: 6) {
                Button(action: { audioVM.toggleInputMute() }) {
                    NerdFontIcon(audioVM.isInputMuted ? config.micMutedIcon : config.micIcon)
                        .foregroundColor(
                            Color(
                                hex: v1Style?.iconColor
                                    ?? (audioVM.isInputMuted
                                        ? config.mutedColor : config.micActiveColor))
                        )
                }
                .buttonStyle(.plain)

                Button(action: { showMicPopover.toggle() }) {
                    HStack(spacing: 4) {
                        Text(String(format: "%.0f%%", audioVM.inputVolume * 100))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: v1Style?.color ?? colors.textPrimary))
                            .frame(width: 30, alignment: .trailing)

                        if isHovered {
                            Text(audioVM.inputFormat)
                                .font(.system(size: 9))
                                .foregroundColor(Color(hex: v1Style?.color ?? colors.textTertiary))
                        }
                    }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showMicPopover, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Input Devices")
                            .font(.headline)
                            .foregroundColor(Color(hex: colors.textPrimary))
                            .padding(.bottom, 5)

                        HStack {
                            NerdFontIcon(config.micMutedIcon, size: 10).foregroundColor(Color(hex: colors.textTertiary))
                            Slider(
                                value: Binding(
                                    get: { audioVM.inputVolume },
                                    set: { audioVM.setInputVolume($0) }), in: 0.0...1.0
                            )
                            .frame(width: 150).accentColor(Color(hex: config.micActiveColor))
                            NerdFontIcon(config.micIcon, size: 10).foregroundColor(Color(hex: colors.textTertiary))
                        }
                        .padding(.bottom, 5)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(audioVM.inputDevices) { device in
                                    Button(action: { audioVM.changeInputDevice(device) }) {
                                        HStack {
                                            Image(
                                                systemName: audioVM.currentInputDevice?.id
                                                    == device.id
                                                    ? "checkmark.circle.fill" : "circle"
                                            )
                                            .foregroundColor(
                                                audioVM.currentInputDevice?.id == device.id
                                                    ? Color(hex: config.micActiveColor) : Color(hex: colors.textTertiary))
                                            Text(device.name).foregroundColor(Color(hex: colors.textPrimary))
                                            Spacer()
                                        }
                                        .frame(width: 200).padding(.vertical, 4).padding(
                                            .horizontal, 8
                                        )
                                        .background(Color(hex: colors.surface)).cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxHeight: 250)
                    }
                    .padding()
                    .background(Color(hex: colors.background))
                }
            }
        }
        .SmoothUIModule()
        .onHover { hover in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { isHovered = hover }
        }
    }
}
