import SwiftUI

struct AudioWidget: View {
    @ObservedObject var audioVM: AudioViewModel
    var theme: Theme
    
    @State private var showAudioPopover = false
    @State private var showMicPopover = false
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 出力 (スピーカー)
            HStack(spacing: 6) {
                Button(action: { audioVM.toggleOutputMute() }) {
                    Image(
                        systemName: audioVM.isOutputMuted
                            ? "speaker.slash.fill" : "speaker.wave.2.fill"
                    )
                    .foregroundColor(audioVM.isOutputMuted ? theme.danger : theme.primary)
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
                            Image(systemName: "speaker.fill").foregroundColor(theme.textTertiary)
                                .font(.system(size: 10))
                            Slider(
                                value: Binding(
                                    get: { audioVM.outputVolume },
                                    set: { audioVM.setOutputVolume($0) }), in: 0.0...1.0
                            )
                            .frame(width: 150).accentColor(theme.primary)
                            Image(systemName: "speaker.wave.3.fill").foregroundColor(
                                theme.textTertiary
                            ).font(.system(size: 10))
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
                                                    ? theme.primary : theme.textTertiary)
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

            // 入力 (マイク)
            HStack(spacing: 6) {
                Button(action: { audioVM.toggleInputMute() }) {
                    Image(systemName: audioVM.isInputMuted ? "mic.slash.fill" : "mic.fill")
                        .foregroundColor(audioVM.isInputMuted ? theme.danger : theme.warning)
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
                            Image(systemName: "mic.fill").foregroundColor(theme.textTertiary).font(
                                .system(size: 10))
                            Slider(
                                value: Binding(
                                    get: { audioVM.inputVolume },
                                    set: { audioVM.setInputVolume($0) }), in: 0.0...1.0
                            )
                            .frame(width: 150).accentColor(theme.warning)
                            Image(systemName: "mic.and.signal.meter.fill").foregroundColor(
                                theme.textTertiary
                            ).font(.system(size: 10))
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
                                                    ? theme.warning : theme.textTertiary)
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
        .onHover { hover in withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { isHovered = hover } }
    }
}
