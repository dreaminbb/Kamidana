import SwiftUI

struct CpuWidget: View {
    @ObservedObject var matrix: SystemMatrix
    var theme: Theme
    
    @State private var showPopover = false
    private var config: CpuWidgetConfig { ConfigManager.shared.currentConfig.cpu }
    
    var body: some View {
        if let cpu = matrix.data.cpuUsage {
            Button(action: { showPopover.toggle() }) {
                HStack(spacing: 4) {
                    NerdFontIcon(config.icon).foregroundColor(getCPUColor(cpu.total, theme: theme))
                    Text(String(format: "%5.1f%%", cpu.total)).foregroundColor(getCPUColor(cpu.total, theme: theme))
                }
            }
            .buttonStyle(.plain)
            .SmoothUIModule(theme: theme)
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("CPU Details")
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                            .padding(.bottom, 4)
                        
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
                        
                        if let topCPU = matrix.data.topCPU, !topCPU.isEmpty {
                            Divider().background(theme.surfaceBorder)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Top Processes").font(.subheadline).foregroundColor(theme.textSecondary)
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
                .frame(maxHeight: 350)
                .background(theme.background)
            }
        }
    }
    
    private func getCPUColor(_ usage: Float, theme: Theme) -> Color {
        if usage < config.successThreshold { return config.successColor.resolve(with: theme) }
        if usage < config.dangerThreshold { return config.cautionColor.resolve(with: theme) }
        return config.dangerColor.resolve(with: theme)
    }
}
