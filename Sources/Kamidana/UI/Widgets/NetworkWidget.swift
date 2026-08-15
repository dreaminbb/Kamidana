import SwiftUI

struct NetworkWidget: View {
    @ObservedObject var matrix: SystemMatrix
    var theme: Theme

    @State private var showPopover = false
    @State private var isHovered = false

    var body: some View {
        if let net = matrix.data.internetUsage {
            Button(action: { showPopover.toggle() }) {
                HStack(spacing: 2) {
                    HStack(spacing: 3) {
                        NerdFontIcon(.arrowUpRight).foregroundColor(theme.info)
                        Text(formatBytes(net.uploadBytesPerSecond) + "/s")
                            .foregroundColor(theme.textPrimary)
                    }
                    HStack(spacing: 3) {
                        NerdFontIcon(.arrowDownRight).foregroundColor(theme.info)
                        Text(formatBytes(net.downloadBytesPerSecond) + "/s")
                            .foregroundColor(theme.textPrimary)
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
                        .foregroundColor(theme.textPrimary)
                        .padding(.bottom, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            NerdFontIcon(.network).foregroundColor(theme.primary).frame(
                                width: 20)
                            Text("Upload:").foregroundColor(theme.textSecondary).frame(
                                width: 70, alignment: .leading)
                            Text("\(formatBytes(net.uploadBytesPerSecond))/s").foregroundColor(
                                theme.info)
                        }
                        HStack {
                            Image(systemName: "").frame(width: 20)
                            Text("Download:").foregroundColor(theme.textSecondary).frame(
                                width: 70, alignment: .leading)
                            Text("\(formatBytes(net.downloadBytesPerSecond))/s").foregroundColor(
                                theme.info)
                        }
                        .font(.system(size: 11, design: .monospaced))
                    }
                }
                .padding()
                .frame(width: 220)
                .background(theme.background)
            }
        }
    }

    // Helper function to format byte counts cleanly
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .binary
        if bytes == 0 { return "0 KB" }
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
