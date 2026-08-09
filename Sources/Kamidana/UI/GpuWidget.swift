import SwiftUI

struct GpuWidget: View {
    @ObservedObject var matrix: SystemMatrix
    var theme: Theme
    
    @State private var showPopover = false
    
    var body: some View {
        if let gpu = matrix.data.gpuUsage {
            Button(action: { showPopover.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: "g.circle.fill").foregroundColor(theme.sky)
                    Text(String(format: "%3.0f%%", gpu.activeRatio)).foregroundColor(theme.sky)
                }
            }
            .buttonStyle(.plain)
            .hyprlandModule(theme: theme)
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("GPU Details")
                        .font(.headline)
                        .foregroundColor(theme.text)
                        .padding(.bottom, 4)
                    
                    HStack {
                        Image(systemName: "g.circle.fill").foregroundColor(theme.sky).frame(width: 20)
                        Text("Utilization:").foregroundColor(theme.subtext1).frame(width: 80, alignment: .leading)
                        Text(String(format: "%.1f%%", gpu.activeRatio)).foregroundColor(theme.text)
                    }
                    .font(.system(size: 11, design: .monospaced))
                }
                .padding()
                .frame(width: 200)
                .background(theme.base)
            }
        }
    }
}
