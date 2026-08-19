import SwiftUI

struct GpuWidget: View {
  @EnvironmentObject var matrix: SystemMatrix
  @Environment(\.kamidanaV1Style) private var v1Style
  @Environment(\.kamidanaWidgetFormat) private var widgetFormat
  @Environment(\.kamidanaWidgetActivation) private var widgetActivation
  @State private var showPopover = false
  @State private var hoverState = WidgetPopoverHoverState()
  let config: GpuWidgetConfig

  var body: some View {
    let colors = ConfigManager.shared.currentConfig.colors
    let gpu = matrix.data.gpuUsage
    let usage = Self.displayUsage(gpu)
    let usageColor = gpu.map { color(for: $0.activeRatio, colors: colors) }
      ?? Color(hex: colors.textTertiary)

    Button(action: { if activation == .click { showPopover.toggle() } }) {
      FormattedWidgetLabel(
        format: widgetFormat ?? "󰢮 {usage}%",
        values: ["usage": usage],
        iconColor: v1Style?.iconColor.map(Color.init(hex:)) ?? usageColor,
        textColor: v1Style?.color.map(Color.init(hex:)) ?? usageColor
      )
    }
    .buttonStyle(WidgetButtonStyle())
    .widgetPopoverActivation($showPopover, activation: activation, hoverState: hoverState)
    .popover(isPresented: $showPopover, arrowEdge: .bottom) {
      popoverContent(colors: colors, gpu: gpu)
        .onHover {
          hoverState.updatePopoverHover($0, isPresented: $showPopover, activation: activation)
        }
    }
  }

  @ViewBuilder
  private func popoverContent(colors: GlobalColorsConfig, gpu: GPUUsageInfo?) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("GPU Details")
        .font(.headline)
        .foregroundColor(Color(hex: colors.textPrimary))

      VStack(alignment: .leading, spacing: 5) {
        detailRow(label: "Usage", value: gpu.map { String(format: "%.1f%%", $0.activeRatio) } ?? "Unavailable", colors: colors)
        detailRow(label: "Status", value: gpu == nil ? "Unsupported or unavailable" : "Available", colors: colors)
        detailRow(label: "Thermal", value: matrix.data.thermalState ?? "Unavailable", colors: colors)
      }
      .font(.system(size: 12, design: .monospaced))

      Divider().overlay(Color(hex: colors.surfaceBorder))
      topProcesses(colors: colors)
    }
    .padding()
    .frame(width: 290, alignment: .leading)
    .background(Color(hex: colors.background))
  }

  private func detailRow(label: String, value: String, colors: GlobalColorsConfig) -> some View {
    HStack {
      Text(label)
        .foregroundColor(Color(hex: colors.textSecondary))
        .frame(width: 76, alignment: .leading)
      Text(value)
        .foregroundColor(Color(hex: colors.textPrimary))
      Spacer(minLength: 0)
    }
  }

  @ViewBuilder
  private func topProcesses(colors: GlobalColorsConfig) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Text("Top GPU Processes")
        .font(.subheadline)
        .foregroundColor(Color(hex: colors.textSecondary))

      if let processes = matrix.data.topGPU, !processes.isEmpty {
        LazyVStack(spacing: 7) {
          ForEach(processes.prefix(SystemMatrix.topProcessLimit)) { process in
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
              Text(String(format: "%.1f%%", process.gpuUsage))
                .foregroundColor(color(for: Float(process.gpuUsage), colors: colors))
                .monospacedDigit()
            }
            .font(.system(size: 12, design: .monospaced))
          }
        }
      } else {
        Text("Collecting GPU process activity...")
          .font(.system(size: 12))
          .foregroundColor(Color(hex: colors.textTertiary))
      }
    }
  }

  static func displayUsage(_ gpu: GPUUsageInfo?) -> String {
    guard let usage = gpu?.activeRatio, usage.isFinite else { return "--" }
    return String(format: "%.1f", usage)
  }

  private var activation: KamidanaActivation { widgetActivation ?? .hover }

  private func color(for usage: Float, colors: GlobalColorsConfig) -> Color {
    if usage < 30 { return Color(hex: colors.success) }
    if usage < 70 { return Color(hex: colors.caution) }
    return Color(hex: colors.danger)
  }
}
