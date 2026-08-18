import SwiftUI

struct MemoryWidget: View {
    @EnvironmentObject var matrix: SystemMatrix
    @Environment(\.kamidanaV1Style) private var v1Style
    @Environment(\.kamidanaWidgetFormat) private var widgetFormat
    @State private var showPopover = false
    @State private var isHovered = false
    let config: MemoryWidgetConfig
    
    var body: some View {
        let colors = ConfigManager.shared.currentConfig.colors
        if let mem = matrix.data.memoryMB {
            Button(action: { showPopover.toggle() }) {
                let usedGB = Double(mem) / 1024.0
                let totalMB = Double(ProcessInfo.processInfo.physicalMemory) / 1_048_576.0
                FormattedWidgetLabel(
                    format: widgetFormat ?? "󰘚 {used_gb} GB",
                    values: [
                        "used_gb": String(format: "%.1f", usedGB),
                        "usage": String(format: "%.1f", Double(mem) / totalMB * 100)
                    ],
                    iconColor: v1Style?.iconColor.map(Color.init(hex:)) ?? Color(hex: config.iconColor),
                    textColor: v1Style?.color.map(Color.init(hex:)) ?? Color(hex: config.textColor)
                )
            }
            .buttonStyle(.plain)
            .SmoothUIModule()
            .onHover { hover in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { isHovered = hover }
            showPopover = hover
        }
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Memory Details")
                            .font(.headline)
                            .foregroundColor(Color(hex: colors.textPrimary))
                            .padding(.bottom, 4)
                        
                        if let topMem = matrix.data.topMemory, !topMem.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Top Processes").font(.subheadline).foregroundColor(Color(hex: colors.textSecondary))
                                ForEach(topMem.prefix(5)) { proc in
                                    HStack {
                                        if let icon = proc.icon {
                                            Image(nsImage: icon).resizable().frame(width: 12, height: 12)
                                        }
                                        Text(proc.name).foregroundColor(Color(hex: colors.textPrimary)).frame(width: 140, alignment: .leading).lineLimit(1)
                                        Spacer()
                                        Text(formatBytes(proc.memoryBytes)).foregroundColor(Color(hex: colors.secondary))
                                    }
                                    .font(.system(size: 11, design: .monospaced))
                                }
                            }
                        } else {
                            Text("Loading processes...").foregroundColor(Color(hex: colors.textTertiary)).font(.system(size: 11))
                        }
                    }
                    .padding()
                    .frame(width: 250)
                }
                .frame(maxHeight: 250)
                .background(Color(hex: colors.background))
            }
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
