import SwiftUI

struct DiskWidget: View {
    @ObservedObject var matrix: SystemMatrix
    var theme: Theme
    
    @State private var showPopover = false
    @State private var isHovered = false
    
    var body: some View {
        if let diskSpace = matrix.data.diskSpace {
            Button(action: { showPopover.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: "internaldrive.fill").foregroundColor(theme.warning)
                    Text(diskSpace)
                        .foregroundColor(theme.warning)
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
                        Text("Disk Details")
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                            .padding(.bottom, 4)
                        
                        if let diskIO = matrix.data.diskIOUsage {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("I/O Speed").font(.subheadline).foregroundColor(theme.textSecondary)
                                HStack {
                                    Image(systemName: "arrow.down.circle").foregroundColor(theme.info).frame(width: 20)
                                    Text("Read:").foregroundColor(theme.textSecondary).frame(width: 50, alignment: .leading)
                                    Text("\(formatBytes(diskIO.readBytesPerSecond))/s").foregroundColor(theme.textPrimary)
                                }
                                HStack {
                                    Image(systemName: "arrow.up.circle").foregroundColor(theme.warning).frame(width: 20)
                                    Text("Write:").foregroundColor(theme.textSecondary).frame(width: 50, alignment: .leading)
                                    Text("\(formatBytes(diskIO.writeBytesPerSecond))/s").foregroundColor(theme.textPrimary)
                                }
                            }
                            .font(.system(size: 11, design: .monospaced))
                        }
                        
                        if let topDisk = matrix.data.topDisk, !topDisk.isEmpty {
                            Divider().background(theme.surfaceBorder)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Top I/O Processes").font(.subheadline).foregroundColor(theme.textSecondary)
                                ForEach(topDisk.prefix(5)) { proc in
                                    HStack {
                                        if let icon = proc.icon {
                                            Image(nsImage: icon).resizable().frame(width: 12, height: 12)
                                        }
                                        Text(proc.name).foregroundColor(theme.textPrimary).frame(width: 120, alignment: .leading).lineLimit(1)
                                        Spacer()
                                        let totalIO = proc.diskReadBytesPerSec + proc.diskWriteBytesPerSec
                                        Text("\(formatBytes(totalIO))/s").foregroundColor(theme.warning)
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
                .frame(maxHeight: 300)
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
