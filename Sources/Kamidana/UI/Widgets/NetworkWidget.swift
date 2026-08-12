import SwiftUI

struct NetworkWidget: View {
    @ObservedObject var matrix: SystemMatrix
    var theme: Theme

    @State private var showPopover = false
    @State private var isHovered = false

    var body: some View {
        if let net = matrix.data.internetUsage {
            Button(action: { showPopover.toggle() }) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.right").foregroundColor(theme.sapphire)
                        Text(formatBytes(net.uploadBytesPerSecond) + "/s")
                            .foregroundColor(theme.text)
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.right").foregroundColor(theme.teal)
                        Text(formatBytes(net.downloadBytesPerSecond) + "/s")
                            .foregroundColor(theme.text)
                    }
                }
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
            }
            .buttonStyle(.plain)
            .SmoothUIModule(theme: theme)
            .onHover { hover in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { isHovered = hover }
                showPopover = hover
            }
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Network Activity")
                        .font(.headline)
                        .foregroundColor(theme.text)
                        .padding(.bottom, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "network").foregroundColor(theme.blue).frame(
                                width: 20)
                            Text("Upload:").foregroundColor(theme.subtext1).frame(
                                width: 70, alignment: .leading)
                            Text("\(formatBytes(net.uploadBytesPerSecond))/s").foregroundColor(
                                theme.sapphire)
                        }
                        HStack {
                            Image(systemName: "").frame(width: 20)
                            Text("Download:").foregroundColor(theme.subtext1).frame(
                                width: 70, alignment: .leading)
                            Text("\(formatBytes(net.downloadBytesPerSecond))/s").foregroundColor(
                                theme.teal)
                        }
                        .font(.system(size: 11, design: .monospaced))
                    }
                }
                .padding()
                .frame(width: 220)
                .background(theme.base)
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
