import AppKit
import SwiftUI

struct CpuGpuWidget: View {
    @ObservedObject var matrix: SystemMatrix
    @Environment(\.kamidanaWidgetActivation) private var widgetActivation
    let config: CpuWidgetConfig
    @State private var showPopover = false
    @State private var hoverState = WidgetPopoverHoverState()
    
    var body: some View {
        let colors = ConfigManager.shared.currentConfig.colors
        Button(action: { if activation == .click { showPopover.toggle() } }) {
            VStack(alignment: .leading, spacing: 2) {
                if let cpu = matrix.data.cpuUsage {
                    HStack(spacing: 4) {
                        NerdFontIcon(config.icon).foregroundColor(getCPUColor(cpu.total))
                        Text(String(format: "%5.1f%%", cpu.total))
                            .foregroundColor(getCPUColor(cpu.total))
                    }
                }

                if let gpu = matrix.data.gpuUsage {
                    HStack(spacing: 4) {
                        gpuIcon
                        Text(String(format: "%3.0f%%", gpu.activeRatio))
                            .foregroundColor(Color(hex: colors.info))
                    }
                }
            }
        }
        .buttonStyle(WidgetButtonStyle())
        .widgetPopoverActivation($showPopover, activation: activation, hoverState: hoverState)
        .widgetPopup(
            isPresented: $showPopover,
            activation: activation,
            hoverState: hoverState
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Processor Details")
                        .font(.headline)
                        .foregroundColor(Color(hex: colors.textPrimary))
                        .padding(.bottom, 4)

                    // CPU Overview
                    if let cpu = matrix.data.cpuUsage {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CPU").font(.subheadline).foregroundColor(Color(hex: colors.textSecondary))
                            HStack {
                                NerdFontIcon(config.icon).foregroundColor(getCPUColor(cpu.total)).frame(width: 20)
                                Text("Total:").foregroundColor(Color(hex: colors.textSecondary)).frame(width: 80, alignment: .leading)
                                Text(String(format: "%.1f%%", cpu.total)).foregroundColor(Color(hex: colors.textPrimary))
                            }
                            .font(.system(size: 11, design: .monospaced))
                        }
                    }
                    
                    // GPU Details
                    if let gpu = matrix.data.gpuUsage {
                        if matrix.data.cpuUsage != nil {
                            Divider().background(Color(hex: colors.surfaceBorder))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("GPU").font(.subheadline).foregroundColor(Color(hex: colors.textSecondary))
                            HStack {
                                gpuIcon.frame(width: 20)
                                Text("Utilization:").foregroundColor(Color(hex: colors.textSecondary)).frame(width: 80, alignment: .leading)
                                Text(String(format: "%.1f%%", gpu.activeRatio)).foregroundColor(Color(hex: colors.textPrimary))
                            }
                            .font(.system(size: 11, design: .monospaced))
                        }
                        Divider().background(Color(hex: colors.surfaceBorder))
                    }
                    
                    // CPU Details
                    if let cpu = matrix.data.cpuUsage {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CPU Cores").font(.subheadline).foregroundColor(Color(hex: colors.textSecondary))
                            HStack(spacing: 4) {
                                ForEach(0..<cpu.perCore.count, id: \.self) { i in
                                    GeometryReader { geo in
                                        VStack {
                                            Spacer(minLength: 0)
                                            Rectangle()
                                                .fill(getCPUColor(cpu.perCore[i]))
                                                .frame(height: max(0, CGFloat(cpu.perCore[i] / 100.0) * geo.size.height))
                                        }
                                    }
                                    .frame(width: 8, height: 30)
                                    .background(Color(hex: colors.surface))
                                    .cornerRadius(2)
                                }
                            }
                        }
                    }
                    
                    // Top Processes (CPU)
                    if let topCPU = matrix.data.topCPU, !topCPU.isEmpty {
                        Divider().background(Color(hex: colors.surfaceBorder))
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Top CPU Processes").font(.subheadline).foregroundColor(Color(hex: colors.textSecondary))
                            ForEach(topCPU.prefix(5)) { proc in
                                HStack {
                                    if let icon = proc.icon {
                                        Image(nsImage: icon).resizable().frame(width: 12, height: 12)
                                    }
                                    Text(proc.name).foregroundColor(Color(hex: colors.textPrimary)).frame(width: 140, alignment: .leading).lineLimit(1)
                                    Spacer()
                                    Text(String(format: "%.1f%%", proc.cpuUsage)).foregroundColor(Color(hex: colors.danger))
                                }
                                .font(.system(size: 11, design: .monospaced))
                            }
                        }
                    }
                }
                .padding()
                .frame(width: 250)
            }
            .frame(maxHeight: 400)
        }
    }

    private var activation: KamidanaActivation { widgetActivation ?? .hover }
    
    private func getCPUColor(_ usage: Float) -> Color {
        let colors = ConfigManager.shared.currentConfig.colors
        if usage < 30.0 { return Color(hex: colors.success) }
        if usage < 70.0 { return Color(hex: colors.caution) }
        return Color(hex: colors.danger)
    }

    @ViewBuilder
    private var gpuIcon: some View {
        let colors = ConfigManager.shared.currentConfig.colors
        if NSFont(name: "JetBrainsMono Nerd Font Mono", size: 12) != nil {
            Text("\u{f8ad}")
                .font(.custom("JetBrainsMono Nerd Font Mono", size: 12))
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
