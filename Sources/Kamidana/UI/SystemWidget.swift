import SwiftUI

struct SystemWidget: View {
    @ObservedObject var matrix: SystemMatrix
    var theme: Theme
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            // コンパクト表示（常に表示）
            if let gpu = matrix.data.gpuUsage {
                HStack(spacing: 4) {
                    Image(systemName: "g.circle.fill").foregroundColor(theme.sky)
                    Text(String(format: "%3.0f%%", gpu.activeRatio)).foregroundColor(theme.sky)
                }
            }
            if let cpu = matrix.data.cpuUsage {
                let cpuColor = getCPUColor(cpu.total, theme: theme)
                HStack(spacing: 4) {
                    Image(systemName: "cpu").foregroundColor(cpuColor)
                    Text(String(format: "%5.1f%%", cpu.total)).foregroundColor(cpuColor)
                }
            }
            if let thermal = matrix.data.thermalState {
                let thermalColor = getThermalColor(thermal, theme: theme)
                HStack(spacing: 4) {
                    Image(systemName: "thermometer").foregroundColor(thermalColor)
                    Text(thermal).foregroundColor(thermalColor)
                }
            }
            if let mem = matrix.data.memoryMB {
                HStack(spacing: 4) {
                    Image(systemName: "memorychip").foregroundColor(theme.mauve)
                    Text(String(format: "%.1f GB", Double(mem) / 1024.0)).foregroundColor(theme.mauve)
                }
            }
            
            // ホバー時展開（トッププロセス）
            if isHovered {
                Divider().frame(height: 16).background(theme.surface2)
                
                HStack(spacing: 12) {
                    if let topCPU = matrix.data.topCPU?.first {
                        HStack(spacing: 2) {
                            Text("CPU:").foregroundColor(theme.subtext1)
                            Text(topCPU.name)
                                .foregroundColor(theme.text)
                                .frame(maxWidth: 60, alignment: .leading)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Text(String(format: "%.1f%%", topCPU.cpuUsage)).foregroundColor(theme.red)
                        }
                    }
                    if let topMem = matrix.data.topMemory?.first {
                        HStack(spacing: 2) {
                            Text("MEM:").foregroundColor(theme.subtext1)
                            Text(topMem.name)
                                .foregroundColor(theme.text)
                                .frame(maxWidth: 60, alignment: .leading)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Text(formatBytes(topMem.memoryBytes)).foregroundColor(theme.mauve)
                        }
                    }
                }
                .font(.system(size: 10))
            }
        }
        .hyprlandModule(theme: theme)
        .onHover { hover in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hover
            }
        }
    }
    
    private func getCPUColor(_ usage: Float, theme: Theme) -> Color {
        if usage < 30.0 { return theme.green }
        if usage < 70.0 { return theme.yellow }
        return theme.red
    }

    private func getThermalColor(_ state: String, theme: Theme) -> Color {
        switch state {
        case "Normal": return theme.sapphire
        case "Warm": return theme.yellow
        case "Hot", "Critical": return theme.red
        default: return theme.text
        }
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .binary
        if bytes == 0 { return "0 KB" }
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
