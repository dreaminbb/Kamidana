import SwiftUI

struct DiskWidget: View {
    @ObservedObject var matrix: SystemMatrix
    @State private var showPopover = false
    @State private var isHovered = false
    let config: DiskWidgetConfig
    
    var body: some View {
        let colors = ConfigManager.shared.currentConfig.colors
        if let diskSpace = matrix.data.diskSpace {
            Button(action: { showPopover.toggle() }) {
                HStack(spacing: 4) {
                    NerdFontIcon(config.icon).foregroundColor(Color(hex: config.iconColor))
                    Text(diskSpace)
                        .foregroundColor(Color(hex: config.textColor))
                }
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
                        Text("Disk Details")
                            .font(.headline)
                            .foregroundColor(Color(hex: colors.textPrimary))
                            .padding(.bottom, 4)
                        
                        if let diskIO = matrix.data.diskIOUsage {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("I/O Speed").font(.subheadline).foregroundColor(Color(hex: colors.textSecondary))
                                HStack {
                                    NerdFontIcon(config.readIcon).foregroundColor(Color(hex: colors.info)).frame(width: 20)
                                    Text("Read:").foregroundColor(Color(hex: colors.textSecondary)).frame(width: 50, alignment: .leading)
                                    Text("\(formatBytes(diskIO.readBytesPerSecond))/s").foregroundColor(Color(hex: colors.textPrimary))
                                }
                                HStack {
                                    NerdFontIcon(config.writeIcon).foregroundColor(Color(hex: colors.warning)).frame(width: 20)
                                    Text("Write:").foregroundColor(Color(hex: colors.textSecondary)).frame(width: 50, alignment: .leading)
                                    Text("\(formatBytes(diskIO.writeBytesPerSecond))/s").foregroundColor(Color(hex: colors.textPrimary))
                                }
                            }
                            .font(.system(size: 11, design: .monospaced))
                        }
                        
                        if let topDisk = matrix.data.topDisk, !topDisk.isEmpty {
                            Divider().background(Color(hex: colors.surfaceBorder))
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Top I/O Processes").font(.subheadline).foregroundColor(Color(hex: colors.textSecondary))
                                ForEach(topDisk.prefix(5)) { proc in
                                    HStack {
                                        if let icon = proc.icon {
                                            Image(nsImage: icon).resizable().frame(width: 12, height: 12)
                                        }
                                        Text(proc.name).foregroundColor(Color(hex: colors.textPrimary)).frame(width: 120, alignment: .leading).lineLimit(1)
                                        Spacer()
                                        let totalIO = proc.diskReadBytesPerSec + proc.diskWriteBytesPerSec
                                        Text("\(formatBytes(totalIO))/s").foregroundColor(Color(hex: colors.warning))
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
                .frame(maxHeight: 300)
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
