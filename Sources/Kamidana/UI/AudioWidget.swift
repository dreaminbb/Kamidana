import SwiftUI

struct AudioWidget: View {
    @ObservedObject var audioVM: AudioViewModel
    var theme: Theme
    
    @State private var showAudioPopover = false
    @State private var showMicPopover = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 出力 (スピーカー)
            HStack(spacing: 6) {
                Button(action: { audioVM.toggleOutputMute() }) {
                    Image(
                        systemName: audioVM.isOutputMuted
                            ? "speaker.slash.fill" : "speaker.wave.2.fill"
                    )
                    .foregroundColor(audioVM.isOutputMuted ? theme.red : theme.blue)
                }
                .buttonStyle(.plain)

                Button(action: { showAudioPopover.toggle() }) {
                    HStack(spacing: 4) {
                        Text(String(format: "%.0f%%", audioVM.outputVolume * 100))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.text)
                            .frame(width: 30, alignment: .trailing)

                        Text(audioVM.outputFormat)
                            .font(.system(size: 9))
                            .foregroundColor(theme.subtext0)
                    }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showAudioPopover, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Output Devices")
                            .font(.headline)
                            .foregroundColor(theme.text)
                            .padding(.bottom, 5)

                        HStack {
                            Image(systemName: "speaker.fill").foregroundColor(theme.subtext0)
                                .font(.system(size: 10))
                            Slider(
                                value: Binding(
                                    get: { audioVM.outputVolume },
                                    set: { audioVM.setOutputVolume($0) }), in: 0.0...1.0
                            )
                            .frame(width: 150).accentColor(theme.blue)
                            Image(systemName: "speaker.wave.3.fill").foregroundColor(
                                theme.subtext0
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
                                                    ? theme.blue : theme.subtext0)
                                            Text(device.name).foregroundColor(theme.text)
                                            Spacer()
                                        }
                                        .frame(width: 200).padding(.vertical, 4).padding(
                                            .horizontal, 8
                                        )
                                        .background(theme.surface0).cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxHeight: 250)
                    }
                    .padding()
                    .background(theme.base)
                }
            }

            // 入力 (マイク)
            HStack(spacing: 6) {
                Button(action: { audioVM.toggleInputMute() }) {
                    Image(systemName: audioVM.isInputMuted ? "mic.slash.fill" : "mic.fill")
                        .foregroundColor(audioVM.isInputMuted ? theme.red : theme.peach)
                }
                .buttonStyle(.plain)

                Button(action: { showMicPopover.toggle() }) {
                    HStack(spacing: 4) {
                        Text(String(format: "%.0f%%", audioVM.inputVolume * 100))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.text)
                            .frame(width: 30, alignment: .trailing)

                        Text(audioVM.inputFormat)
                            .font(.system(size: 9))
                            .foregroundColor(theme.subtext0)
                    }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showMicPopover, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Input Devices")
                            .font(.headline)
                            .foregroundColor(theme.text)
                            .padding(.bottom, 5)

                        HStack {
                            Image(systemName: "mic.fill").foregroundColor(theme.subtext0).font(
                                .system(size: 10))
                            Slider(
                                value: Binding(
                                    get: { audioVM.inputVolume },
                                    set: { audioVM.setInputVolume($0) }), in: 0.0...1.0
                            )
                            .frame(width: 150).accentColor(theme.peach)
                            Image(systemName: "mic.and.signal.meter.fill").foregroundColor(
                                theme.subtext0
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
                                                    ? theme.peach : theme.subtext0)
                                            Text(device.name).foregroundColor(theme.text)
                                            Spacer()
                                        }
                                        .frame(width: 200).padding(.vertical, 4).padding(
                                            .horizontal, 8
                                        )
                                        .background(theme.surface0).cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxHeight: 250)
                    }
                    .padding()
                    .background(theme.base)
                }
            }
        }
        .hyprlandModule(theme: theme)
    }
}
