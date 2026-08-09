import SwiftUI

struct NetworkWidget: View {
    @ObservedObject var matrix: SystemMatrix
    var theme: Theme
    
    @State private var isHovered = false
    
    var body: some View {
        if let net = matrix.data.internetUsage {
            HStack(spacing: 8) {
                // コンパクト表示：ネット通信速度
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.right").foregroundColor(theme.sapphire)
                    Text(formatBytes(net.uploadBytesPerSecond) + "/s").foregroundColor(theme.text)
                }
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.right").foregroundColor(theme.teal)
                    Text(formatBytes(net.downloadBytesPerSecond) + "/s").foregroundColor(theme.text)
                }
                
                // ホバー時展開：ディスクI/O速度
                if isHovered, let disk = matrix.data.diskIOUsage {
                    Divider().frame(height: 16).background(theme.surface2)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "internaldrive").foregroundColor(theme.mauve)
                        HStack(spacing: 3) {
                            Text("R:").foregroundColor(theme.subtext1)
                            Text("\(formatBytes(disk.readBytesPerSecond))/s").foregroundColor(theme.text)
                        }
                        HStack(spacing: 3) {
                            Text("W:").foregroundColor(theme.subtext1)
                            Text("\(formatBytes(disk.writeBytesPerSecond))/s").foregroundColor(theme.text)
                        }
                    }
                }
            }
            .hyprlandModule(theme: theme)
            .onHover { hover in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isHovered = hover
                }
            }
        }
    }
    
    // バイト数を綺麗にフォーマットするヘルパー関数
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .binary
        if bytes == 0 { return "0 KB" }
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
