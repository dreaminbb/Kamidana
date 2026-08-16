import AppKit
import SwiftUI

struct CpuGpuWidget: View {
    @ObservedObject var matrix: SystemMatrix
    var theme: Theme
    
    @State private var showPopover = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: { showPopover.toggle() }) {
            VStack(alignment: .leading, spacing: 2) {
                if let cpu = matrix.data.cpuUsage {
                    HStack(spacing: 4) {
                        NerdFontIcon(ConfigManager.shared.currentConfig.cpu.icon).foregroundColor(getCPUColor(cpu.total, theme: theme))
                        Text(String(format: "%5.1f%%", cpu.total))
                            .foregroundColor(getCPUColor(cpu.total, theme: theme))
                    }
                }

                if let gpu = matrix.data.gpuUsage {
                    HStack(spacing: 4) {
                        gpuIcon
                        Text(String(format: "%3.0f%%", gpu.activeRatio))
                            .foregroundColor(theme.info)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .SmoothUIModule(theme: theme)
        .onHover { hover in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { isHovered = hover }
            showPopover = hover
        }
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Processor Details")
                        .font(.headline)
                        .foregroundColor(theme.textPrimary)
                        .padding(.bottom, 4)

                    // CPU Overview
                    if let cpu = matrix.data.cpuUsage {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CPU").font(.subheadline).foregroundColor(theme.textSecondary)
                            HStack {
                                NerdFontIcon(ConfigManager.shared.currentConfig.cpu.icon).foregroundColor(getCPUColor(cpu.total, theme: theme)).frame(width: 20)
                                Text("Total:").foregroundColor(theme.textSecondary).frame(width: 80, alignment: .leading)
                                Text(String(format: "%.1f%%", cpu.total)).foregroundColor(theme.textPrimary)
                            }
                            .font(.system(size: 11, design: .monospaced))
                        }
                    }
                    
                    // GPU Details
                    if let gpu = matrix.data.gpuUsage {
                        if matrix.data.cpuUsage != nil {
                            Divider().background(theme.surfaceBorder)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("GPU").font(.subheadline).foregroundColor(theme.textSecondary)
                            HStack {
                                gpuIcon.frame(width: 20)
                                Text("Utilization:").foregroundColor(theme.textSecondary).frame(width: 80, alignment: .leading)
                                Text(String(format: "%.1f%%", gpu.activeRatio)).foregroundColor(theme.textPrimary)
                            }
                            .font(.system(size: 11, design: .monospaced))
                        }
                        Divider().background(theme.surfaceBorder)
                    }
                    
                    // CPU Details
                    if let cpu = matrix.data.cpuUsage {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CPU Cores").font(.subheadline).foregroundColor(theme.textSecondary)
                            HStack(spacing: 4) {
                                ForEach(0..<cpu.perCore.count, id: \.self) { i in
                                    GeometryReader { geo in
                                        VStack {
                                            Spacer(minLength: 0)
                                            Rectangle()
                                                .fill(getCPUColor(cpu.perCore[i], theme: theme))
                                                .frame(height: max(0, CGFloat(cpu.perCore[i] / 100.0) * geo.size.height))
                                        }
                                    }
                                    .frame(width: 8, height: 30)
                                    .background(theme.surface)
                                    .cornerRadius(2)
                                }
                            }
                        }
                    }
                    
                    // Top Processes (CPU)
                    if let topCPU = matrix.data.topCPU, !topCPU.isEmpty {
                        Divider().background(theme.surfaceBorder)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Top CPU Processes").font(.subheadline).foregroundColor(theme.textSecondary)
                            ForEach(topCPU.prefix(5)) { proc in
                                HStack {
                                    if let icon = proc.icon {
                                        Image(nsImage: icon).resizable().frame(width: 12, height: 12)
                                    }
                                    Text(proc.name).foregroundColor(theme.textPrimary).frame(width: 140, alignment: .leading).lineLimit(1)
                                    Spacer()
                                    Text(String(format: "%.1f%%", proc.cpuUsage)).foregroundColor(theme.danger)
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
            .background(theme.background)
        }
    }
    
    private func getCPUColor(_ usage: Float, theme: Theme) -> Color {
        if usage < 30.0 { return theme.success }
        if usage < 70.0 { return theme.caution }
        return theme.danger
    }

    @ViewBuilder
    private var gpuIcon: some View {
        if NSFont(name: "JetBrainsMono Nerd Font Mono", size: 12) != nil {
            Text("\u{f8ad}")
                .font(.custom("JetBrainsMono Nerd Font Mono", size: 12))
                .foregroundColor(theme.info)
                .frame(width: 14, height: 14, alignment: .center)
                .clipped()
        } else {
            Text("GPU")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(theme.info)
                .frame(width: 14, height: 14, alignment: .center)
        }
    }
}
