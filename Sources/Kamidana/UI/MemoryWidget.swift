import SwiftUI

struct MemoryWidget: View {
    @ObservedObject var matrix: SystemMatrix
    var theme: Theme
    
    @State private var showPopover = false
    @State private var isHovered = false
    
    var body: some View {
        if let mem = matrix.data.memoryMB {
            Button(action: { showPopover.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: "memorychip").foregroundColor(theme.mauve)
                    Text(String(format: "%.1f GB", Double(mem) / 1024.0))
                        .foregroundColor(theme.mauve)
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
                            .foregroundColor(theme.text)
                            .padding(.bottom, 4)
                        
                        if let topMem = matrix.data.topMemory, !topMem.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Top Processes").font(.subheadline).foregroundColor(theme.subtext1)
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
                        } else {
                            Text("Loading processes...").foregroundColor(theme.subtext0).font(.system(size: 11))
                        }
                    }
                    .padding()
                    .frame(width: 250)
                }
                .frame(maxHeight: 250)
                .background(theme.base)
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
