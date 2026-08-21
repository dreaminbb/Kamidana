import SwiftUI

struct CpuWidget: View {
  static let processListLimit = SystemMatrix.topProcessLimit

  @EnvironmentObject var matrix: SystemMatrix
  @Environment(\.kamidanaV1Style) private var v1Style
  @Environment(\.kamidanaWidgetFormat) private var widgetFormat
  @Environment(\.kamidanaWidgetActivation) private var widgetActivation
  @State private var showPopover = false
  @State private var hoverState = WidgetPopoverHoverState()
  let config: CpuWidgetConfig

  var body: some View {
    let colors = ConfigManager.shared.currentConfig.colors
    let cpu = matrix.data.cpuUsage
    let usage = cpu.map { String(format: "%.1f", $0.total) } ?? "--"

    Button(action: { if activation == .click { showPopover.toggle() } }) {
      FormattedWidgetLabel(
        format: widgetFormat ?? "󰍛 {usage}%",
        values: ["usage": usage],
        iconColor: v1Style?.iconColor.map(Color.init(hex:)) ?? cpu.map { getCPUColor($0.total) }
          ?? Color(hex: colors.textTertiary),
        textColor: v1Style?.color.map(Color.init(hex:)) ?? cpu.map { getCPUColor($0.total) }
          ?? Color(hex: colors.textTertiary)
      )
    }
    .buttonStyle(WidgetButtonStyle())
    .widgetPopoverActivation($showPopover, activation: activation, hoverState: hoverState)
    .widgetPopup(
      isPresented: $showPopover,
      activation: activation,
      hoverState: hoverState
    ) {
      popoverContent(colors: colors, cpu: cpu)
    }
  }

  @ViewBuilder
  private func popoverContent(colors: GlobalColorsConfig, cpu: CPUUsageInfo?) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("CPU Details")
        .font(.headline)
        .foregroundColor(Color(hex: colors.textPrimary))

      details(cpu: cpu, colors: colors)

      if Self.canDisplayCoreGraph(for: cpu) {
        Divider().overlay(Color(hex: colors.surfaceBorder))
        coreGraph(cpu?.perCore ?? [], colors: colors)
      } else {
        Text("Per-core usage is unavailable.")
          .font(.system(size: 12))
          .foregroundColor(Color(hex: colors.textTertiary))
      }

      Divider().overlay(Color(hex: colors.surfaceBorder))
      topProcesses(colors: colors)
    }
    .padding()
    .frame(width: 290, alignment: .leading)
  }

  @ViewBuilder
  private func details(cpu: CPUUsageInfo?, colors: GlobalColorsConfig) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      detailRow(
        label: "Usage",
        value: cpu.map { String(format: "%.1f%%", $0.total) } ?? "Unavailable",
        colors: colors
      )
      detailRow(
        label: "Processes",
        value: matrix.data.processCount.map(String.init) ?? "Unavailable",
        colors: colors
      )
      detailRow(
        label: "Threads",
        value: matrix.data.threadCount.map(String.init) ?? "Unavailable",
        colors: colors
      )
    }
    .font(.system(size: 12, design: .monospaced))
  }

  private func detailRow(label: String, value: String, colors: GlobalColorsConfig) -> some View {
    HStack {
      Text(label)
        .foregroundColor(Color(hex: colors.textSecondary))
        .frame(width: 82, alignment: .leading)
      Text(value)
        .foregroundColor(Color(hex: colors.textPrimary))
      Spacer(minLength: 0)
    }
  }

  @ViewBuilder
  private func coreGraph(_ perCore: [Float], colors: GlobalColorsConfig) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Text("Cores")
        .font(.subheadline)
        .foregroundColor(Color(hex: colors.textSecondary))

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .bottom, spacing: 4) {
          ForEach(Array(perCore.enumerated()), id: \.offset) { index, usage in
            VStack(spacing: 3) {
              GeometryReader { geometry in
                VStack {
                  Spacer(minLength: 0)
                  RoundedRectangle(cornerRadius: 2)
                    .fill(getCPUColor(usage))
                    .frame(height: max(2, CGFloat(usage / 100) * geometry.size.height))
                }
              }
              .frame(width: 11, height: 42)
              .background(Color(hex: colors.surface))
              .clipShape(RoundedRectangle(cornerRadius: 2))

              Text("\(index + 1)")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(Color(hex: colors.textTertiary))
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private func topProcesses(colors: GlobalColorsConfig) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Text("Top Processes")
        .font(.subheadline)
        .foregroundColor(Color(hex: colors.textSecondary))

      if let processes = matrix.data.topCPU, !processes.isEmpty {
        LazyVStack(spacing: 7) {
          ForEach(processes.prefix(Self.processListLimit)) { process in
            processRow(process, colors: colors)
          }
        }
      } else {
        Text("Process data is unavailable.")
          .font(.system(size: 12))
          .foregroundColor(Color(hex: colors.textTertiary))
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
      Text(String(format: "%.1f%%", process.cpuUsage))
        .foregroundColor(getCPUColor(Float(process.cpuUsage)))
        .monospacedDigit()
    }
    .font(.system(size: 12, design: .monospaced))
  }

  static func canDisplayCoreGraph(for cpu: CPUUsageInfo?) -> Bool {
    guard let cpu, !cpu.perCore.isEmpty else { return false }
    return cpu.perCore.allSatisfy { $0.isFinite && $0 >= 0 }
  }

  private var activation: KamidanaActivation { widgetActivation ?? .hover }

  private func getCPUColor(_ usage: Float) -> Color {
    if usage < config.successThreshold { return Color(hex: config.successColor) }
    if usage < config.dangerThreshold { return Color(hex: config.cautionColor) }
    return Color(hex: config.dangerColor)
  }
}
