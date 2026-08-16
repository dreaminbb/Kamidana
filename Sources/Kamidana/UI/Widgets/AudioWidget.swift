import SwiftUI

struct AudioWidget: View {
    @ObservedObject var audioVM: AudioViewModel
    var theme: Theme

    @State private var showAudioPopover = false
    @State private var showMicPopover = false
    @State private var isHovered = false

    var config: AudioWidgetConfig { ConfigManager.shared.currentConfig.audio }

    var body: some View {
        HStack(spacing: 12) {
            // Output (Speaker)
            HStack(spacing: 6) {
                Button(action: { audioVM.toggleOutputMute() }) {
                    NerdFontIcon(audioVM.isOutputMuted ? config.speakerMutedIcon : config.speakerIcon)
                    .foregroundColor(audioVM.isOutputMuted ? config.mutedColor.resolve(with: theme) : config.activeColor.resolve(with: theme))
                }
                .buttonStyle(.plain)

                Button(action: { showAudioPopover.toggle() }) {
                    HStack(spacing: 4) {
                        Text(String(format: "%.0f%%", audioVM.outputVolume * 100))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.textPrimary)
                            .frame(width: 30, alignment: .trailing)

                        if isHovered {
                            Text(audioVM.outputFormat)
                                .font(.system(size: 9))
                                .foregroundColor(theme.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showAudioPopover, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Output Devices")
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                            .padding(.bottom, 5)

                        HStack {
                            NerdFontIcon(config.speakerMutedIcon, size: 10).foregroundColor(theme.textTertiary)
                            Slider(
                                value: Binding(
                                    get: { audioVM.outputVolume },
                                    set: { audioVM.setOutputVolume($0) }), in: 0.0...1.0
                            )
                            .frame(width: 150).accentColor(config.activeColor.resolve(with: theme))
                            NerdFontIcon(config.speakerIcon, size: 10).foregroundColor(
                                theme.textTertiary
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
                                                    ? config.activeColor.resolve(with: theme) : theme.textTertiary)
                                            Text(device.name).foregroundColor(theme.textPrimary)
                                            Spacer()
                                        }
                                        .frame(width: 200).padding(.vertical, 4).padding(
                                            .horizontal, 8
                                        )
                                        .background(theme.surface).cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxHeight: 250)
                    }
                    .padding()
                    .background(theme.background)
                }
            }

            // Input (Microphone)
            HStack(spacing: 6) {
                Button(action: { audioVM.toggleInputMute() }) {
                    NerdFontIcon(audioVM.isInputMuted ? config.micMutedIcon : config.micIcon)
                        .foregroundColor(audioVM.isInputMuted ? config.mutedColor.resolve(with: theme) : config.micActiveColor.resolve(with: theme))
                }
                .buttonStyle(.plain)

                Button(action: { showMicPopover.toggle() }) {
                    HStack(spacing: 4) {
                        Text(String(format: "%.0f%%", audioVM.inputVolume * 100))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.textPrimary)
                            .frame(width: 30, alignment: .trailing)

                        if isHovered {
                            Text(audioVM.inputFormat)
                                .font(.system(size: 9))
                                .foregroundColor(theme.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showMicPopover, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Input Devices")
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                            .padding(.bottom, 5)

                        HStack {
                            NerdFontIcon(config.micMutedIcon, size: 10).foregroundColor(theme.textTertiary)
                            Slider(
                                value: Binding(
                                    get: { audioVM.inputVolume },
                                    set: { audioVM.setInputVolume($0) }), in: 0.0...1.0
                            )
                            .frame(width: 150).accentColor(config.micActiveColor.resolve(with: theme))
                            NerdFontIcon(config.micIcon, size: 10).foregroundColor(theme.textTertiary)
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
                                                    ? config.micActiveColor.resolve(with: theme) : theme.textTertiary)
                                            Text(device.name).foregroundColor(theme.textPrimary)
                                            Spacer()
                                        }
                                        .frame(width: 200).padding(.vertical, 4).padding(
                                            .horizontal, 8
                                        )
                                        .background(theme.surface).cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxHeight: 250)
                    }
                    .padding()
                    .background(theme.background)
                }
            }
        }
        .SmoothUIModule(theme: theme)
        .onHover { hover in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { isHovered = hover }
        }
    }
}
