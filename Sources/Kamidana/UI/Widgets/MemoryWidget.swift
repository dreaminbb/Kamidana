import SwiftUI

struct MemoryWidget: View {
    @EnvironmentObject var matrix: SystemMatrix
    @Environment(\.kamidanaV1Style) private var v1Style
    @Environment(\.kamidanaWidgetFormat) private var widgetFormat
    @Environment(\.kamidanaWidgetActivation) private var widgetActivation
    @State private var showPopover = false
    @State private var hoverState = WidgetPopoverHoverState()
    @State private var isHovered = false
    let config: MemoryWidgetConfig
    
    var body: some View {
        let colors = ConfigManager.shared.currentConfig.colors
        if let mem = matrix.data.memoryMB {
            let values = Self.formatValues(
                usedMB: mem,
                totalBytes: ProcessInfo.processInfo.physicalMemory
            )
            Button(action: { if activation == .click { showPopover.toggle() } }) {
                FormattedWidgetLabel(
                    format: widgetFormat ?? "󰘚 {used_gb} / {total_gb} GB",
                    values: values,
                    iconColor: v1Style?.iconColor.map(Color.init(hex:)) ?? Color(hex: config.iconColor),
                    textColor: v1Style?.color.map(Color.init(hex:)) ?? Color(hex: config.textColor)
                )
            }
            .buttonStyle(WidgetButtonStyle())
            .widgetPopoverActivation($showPopover, activation: activation, hoverState: hoverState)
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Memory Details")
                        .font(.headline)
                        .foregroundColor(Color(hex: colors.textPrimary))

                    VStack(alignment: .leading, spacing: 5) {
                        memoryDetailRow(label: "Used", value: "\(values["used_gb"] ?? "--") GB", colors: colors)
                        memoryDetailRow(label: "Maximum", value: "\(values["total_gb"] ?? "--") GB", colors: colors)
                        memoryDetailRow(label: "Usage", value: "\(values["usage"] ?? "--")%", colors: colors)
                    }
                    .font(.system(size: 12, design: .monospaced))

                    Divider().overlay(Color(hex: colors.surfaceBorder))
                    topProcesses(colors: colors)
                }
                .padding()
                .frame(width: 300, alignment: .leading)
                .background(Color(hex: colors.background))
                .onHover {
                    hoverState.updatePopoverHover($0, isPresented: $showPopover, activation: activation)
                }
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

    @ViewBuilder
    private func topProcesses(colors: GlobalColorsConfig) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Top Processes")
                .font(.subheadline)
                .foregroundColor(Color(hex: colors.textSecondary))

            if let processes = matrix.data.topMemory, !processes.isEmpty {
                LazyVStack(spacing: 7) {
                    ForEach(processes.prefix(SystemMatrix.topProcessLimit)) { process in
                        processRow(process, colors: colors)
                    }
                }
            } else {
                Text("Loading processes...")
                    .foregroundColor(Color(hex: colors.textTertiary))
                    .font(.system(size: 12))
            }
        }
    }

    private func processRow(_ process: ProcessStat, colors: GlobalColorsConfig) -> some View {
        HStack(spacing: 7) {
            if let icon = process.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 14, height: 14)
            }
            Text(process.name)
                .foregroundColor(Color(hex: colors.textPrimary))
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(formatBytes(process.memoryBytes))
                .foregroundColor(Color(hex: colors.secondary))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .font(.system(size: 12, design: .monospaced))
    }

    private func memoryDetailRow(label: String, value: String, colors: GlobalColorsConfig) -> some View {
        HStack {
            Text(label)
                .foregroundColor(Color(hex: colors.textSecondary))
                .frame(width: 74, alignment: .leading)
            Text(value)
                .foregroundColor(Color(hex: colors.textPrimary))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 0)
        }
    }

    static func formatValues(usedMB: UInt64, totalBytes: UInt64) -> [String: String] {
        let usedGB = Double(usedMB) / 1024
        let totalGB = Double(totalBytes) / 1_073_741_824
        let usage = totalGB > 0 ? usedGB / totalGB * 100 : 0
        return [
            "used_gb": String(format: "%.1f", usedGB),
            "total_gb": String(format: "%.1f", totalGB),
            "usage": String(format: "%.1f", usage),
        ]
    }

    private var activation: KamidanaActivation { widgetActivation ?? .hover }
}
