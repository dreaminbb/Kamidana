import SwiftUI

struct MemoryWidget: View {
    @ObservedObject var matrix: SystemMatrix
    var theme: Theme
    
    @State private var showPopover = false
    @State private var isHovered = false
    private var config: MemoryWidgetConfig { ConfigManager.shared.currentConfig.memory }
    
    var body: some View {
        if let mem = matrix.data.memoryMB {
            Button(action: { showPopover.toggle() }) {
                HStack(spacing: 4) {
                    NerdFontIcon(config.icon).foregroundColor(config.iconColor.resolve(with: theme))
                    Text(String(format: "%.1f GB", Double(mem) / 1024.0))
                        .foregroundColor(config.textColor.resolve(with: theme))
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
                        Text("Memory Details")
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                            .padding(.bottom, 4)
                        
                        if let topMem = matrix.data.topMemory, !topMem.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Top Processes").font(.subheadline).foregroundColor(theme.textSecondary)
                                ForEach(topMem.prefix(5)) { proc in
                                    HStack {
                                        if let icon = proc.icon {
                                            Image(nsImage: icon).resizable().frame(width: 12, height: 12)
                                        }
                                        Text(proc.name).foregroundColor(theme.textPrimary).frame(width: 140, alignment: .leading).lineLimit(1)
                                        Spacer()
                                        Text(formatBytes(proc.memoryBytes)).foregroundColor(theme.secondary)
                                    }
                                    .font(.system(size: 11, design: .monospaced))
                                }
                            }
                        } else {
                            Text("Loading processes...").foregroundColor(theme.textTertiary).font(.system(size: 11))
                        }
                    }
                    .padding()
                    .frame(width: 250)
                }
                .frame(maxHeight: 250)
                .background(theme.background)
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
