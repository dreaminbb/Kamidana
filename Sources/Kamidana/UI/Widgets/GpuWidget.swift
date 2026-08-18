import AppKit
import SwiftUI

struct GpuWidget: View {
    @EnvironmentObject var matrix: SystemMatrix
    @Environment(\.kamidanaV1Style) private var v1Style
    @Environment(\.kamidanaWidgetFormat) private var widgetFormat
    @State private var showPopover = false
    let config: GpuWidgetConfig

    var body: some View {
        let colors = ConfigManager.shared.currentConfig.colors
        if let gpu = matrix.data.gpuUsage {
            Button(action: { showPopover.toggle() }) {
                FormattedWidgetLabel(
                    format: widgetFormat ?? "󰢮 {usage}%",
                    values: ["usage": String(format: "%.1f", gpu.activeRatio)],
                    iconColor: v1Style?.iconColor.map(Color.init(hex:)) ?? Color(hex: colors.info),
                    textColor: v1Style?.color.map(Color.init(hex:)) ?? Color(hex: colors.info)
                )
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
        NerdFontIcon("󰢮", size: 20)
            .foregroundColor(Color(hex: colors.info))
    }
}
