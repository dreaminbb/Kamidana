import SwiftUI

struct SystemWidget: View {
    @ObservedObject var matrix: SystemMatrix
    var theme: Theme
    
    @State private var showPopover = false
    
    var body: some View {
        Button(action: { showPopover.toggle() }) {
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
            }
        }
        .buttonStyle(.plain)
        .hyprlandModule(theme: theme)
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("System Details")
                        .font(.headline)
                        .foregroundColor(theme.text)
                        .padding(.bottom, 4)
                    
                    if let cpu = matrix.data.cpuUsage {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CPU Cores").font(.subheadline).foregroundColor(theme.subtext1)
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
                                    .background(theme.surface0)
                                    .cornerRadius(2)
                                }
                            }
                        }
                    }
                    
                    if let topCPU = matrix.data.topCPU, !topCPU.isEmpty {
                        Divider().background(theme.surface2)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Top CPU Processes").font(.subheadline).foregroundColor(theme.subtext1)
                            ForEach(topCPU.prefix(5)) { proc in
                                HStack {
                                    if let icon = proc.icon {
                                        Image(nsImage: icon).resizable().frame(width: 12, height: 12)
                                    }
                                    Text(proc.name).foregroundColor(theme.text).frame(width: 140, alignment: .leading).lineLimit(1)
                                    Spacer()
                                    Text(String(format: "%.1f%%", proc.cpuUsage)).foregroundColor(theme.red)
                                }
                                .font(.system(size: 11, design: .monospaced))
                            }
                        }
                    }
                    
                    if let topMem = matrix.data.topMemory, !topMem.isEmpty {
                        Divider().background(theme.surface2)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Top Memory Processes").font(.subheadline).foregroundColor(theme.subtext1)
                            ForEach(topMem.prefix(5)) { proc in
                                HStack {
                                    if let icon = proc.icon {
                                        Image(nsImage: icon).resizable().frame(width: 12, height: 12)
                                    }
                                    Text(proc.name).foregroundColor(theme.text).frame(width: 140, alignment: .leading).lineLimit(1)
                                    Spacer()
                                    Text(formatBytes(proc.memoryBytes)).foregroundColor(theme.mauve)
                                }
                                .font(.system(size: 11, design: .monospaced))
                            }
                        }
                    }
                }
                .padding()
                .frame(width: 280)
            }
            .frame(maxHeight: 400)
            .background(theme.base)
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
