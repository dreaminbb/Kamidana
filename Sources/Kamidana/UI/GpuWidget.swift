import AppKit
import SwiftUI

struct GpuWidget: View {
    @ObservedObject var matrix: SystemMatrix
    var theme: Theme

    @State private var showPopover = false

    var body: some View {
        if let gpu = matrix.data.gpuUsage {
            Button(action: { showPopover.toggle() }) {
                HStack(spacing: 1) {
                    gpuIcon
                    Text(String(format: "%5.1f%%", gpu.activeRatio))
                        .foregroundColor(theme.sky)
                }
            }
            .buttonStyle(.plain)
            .SmoothUIModule(theme: theme)
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("GPU Details")
                        .font(.headline)
                        .foregroundColor(theme.text)
                        .padding(.bottom, 4)

                    HStack {
                        gpuIcon.frame(width: 20)
                        Text("Usage:")
                            .foregroundColor(theme.subtext1)
                            .frame(width: 80, alignment: .leading)
                        Text(String(format: "%.1f%%", gpu.activeRatio))
                            .foregroundColor(theme.text)
                    }
                    .font(.system(size: 11, design: .monospaced))

                    if let topCPU = matrix.data.topCPU, !topCPU.isEmpty {
                        Divider().background(theme.surface2)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Top Processes")
                                .font(.subheadline)
                                .foregroundColor(theme.subtext1)
                            ForEach(topCPU.prefix(5)) { proc in
                                HStack {
                                    if let icon = proc.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 12, height: 12)
                                    }
                                    Text(proc.name)
                                        .foregroundColor(theme.text)
                                        .frame(width: 140, alignment: .leading)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(String(format: "%.1f%%", proc.cpuUsage))
                                        .foregroundColor(theme.red)
                                }
                                .font(.system(size: 11, design: .monospaced))
                            }
                        }
                    }
                }
                .padding()
                .frame(width: 230)
                .background(theme.base)
            }
        }
    }

    @ViewBuilder
    private var gpuIcon: some View {
        if NSFont(name: "JetBrainsMono Nerd Font Mono", size: 12) != nil {
            Text("󰾲")
                .font(.custom("JetBrainsMono Nerd Font Mono", size: 25))
                .foregroundColor(theme.sky)
                .frame(width: 14, height: 14, alignment: .center)
                .clipped()
        } else {
            Text("GPU")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(theme.sky)
                .frame(width: 14, height: 14, alignment: .center)
        }
    }
}
