import AppKit
import SwiftUI

struct GpuWidget: View {
    @ObservedObject var matrix: SystemMatrix
    @State private var showPopover = false

    var body: some View {
        let colors = ConfigManager.shared.currentConfig.colors
        if let gpu = matrix.data.gpuUsage {
            Button(action: { showPopover.toggle() }) {
                HStack(spacing: 1) {
                    NerdFontIcon("󰢮")
                        .foregroundColor(Color(hex: colors.info))
                        .frame(width: 14, height: 14, alignment: .center)
                        .clipped()
                    Text(String(format: "%5.1f%%", gpu.activeRatio))
                        .foregroundColor(Color(hex: colors.info))
                }
            }
            .buttonStyle(.plain)
            .SmoothUIModule()
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("GPU Details")
                        .font(.headline)
                        .foregroundColor(Color(hex: colors.textPrimary))
                        .padding(.bottom, 4)

                    HStack {
                        gpuIcon.frame(width: 20)
                        Text("Usage:")
                            .foregroundColor(Color(hex: colors.textSecondary))
                            .frame(width: 80, alignment: .leading)
                        Text(String(format: "%.1f%%", gpu.activeRatio))
                            .foregroundColor(Color(hex: colors.textPrimary))
                    }
                    .font(.system(size: 11, design: .monospaced))

                    if let topCPU = matrix.data.topCPU, !topCPU.isEmpty {
                        Divider().background(Color(hex: colors.surfaceBorder))
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Top Processes")
                                .font(.subheadline)
                                .foregroundColor(Color(hex: colors.textSecondary))
                            ForEach(topCPU.prefix(5)) { proc in
                                HStack {
                                    if let icon = proc.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 12, height: 12)
                                    }
                                    Text(proc.name)
                                        .foregroundColor(Color(hex: colors.textPrimary))
                                        .frame(width: 140, alignment: .leading)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(String(format: "%.1f%%", proc.cpuUsage))
                                        .foregroundColor(Color(hex: colors.danger))
                                }
                                .font(.system(size: 11, design: .monospaced))
                            }
                        }
                    }
                }
                .padding()
                .frame(width: 230)
                .background(Color(hex: colors.background))
            }
        }
    }

    @ViewBuilder
    private var gpuIcon: some View {
        let colors = ConfigManager.shared.currentConfig.colors
        if NSFont(name: "JetBrainsMono Nerd Font Mono", size: 12) != nil {
            Text("󰾲")
                .font(.custom("JetBrainsMono Nerd Font Mono", size: 25))
                .foregroundColor(Color(hex: colors.info))
                .frame(width: 14, height: 14, alignment: .center)
                .clipped()
        } else {
            Text("GPU")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: colors.info))
                .frame(width: 14, height: 14, alignment: .center)
        }
    }
}
