import SwiftUI

struct BatteryWidget: View {
  @EnvironmentObject var matrix: SystemMatrix
  @Environment(\.kamidanaV1Style) private var v1Style
  @Environment(\.kamidanaWidgetFormat) private var widgetFormat
  @State private var showPopover = false
  @State private var isHovered = false

  let config: BatteryWidgetConfig

  private func resolveBatteryIcon(capacity: Int64, isCharging: Bool) -> String {
    if isCharging {
      return config.charging_right_now
    }
    switch capacity {
    case 95...100: return config._100_capacity
    case 85..<95: return config._90_capacity
    case 75..<85: return config._80_capacity
    case 65..<75: return config._70_capacity
    case 55..<65: return config._60_capacity
    case 45..<55: return config._50_capacity
    case 35..<45: return config._40_capacity
    case 25..<35: return config._30_capacity
    case 15..<25: return config._20_capacity
    case 10..<15: return config._10_capacity
    default: return config._sub_10_charged
    }
  }

  var body: some View {
    let colors = ConfigManager.shared.currentConfig.colors
    if let battery = matrix.data.batteryUsage {
      Button(action: { showPopover.toggle() }) {
        let statusColor = battery.isCharging
          ? Color(hex: config.chargingColor) : Color(hex: config.dischargingColor)
        FormattedWidgetLabel(
          format: widgetFormat ?? "{icon} {capacity}%",
          values: [
            "icon": resolveBatteryIcon(
              capacity: battery.currentCapacity,
              isCharging: battery.isCharging
            ),
            "capacity": "\(battery.currentCapacity)",
            "status": battery.isCharging ? "charging" : "discharging"
          ],
          iconColor: v1Style?.iconColor.map(Color.init(hex:)) ?? statusColor,
          textColor: v1Style?.color.map(Color.init(hex:)) ?? statusColor
        )
      }
      .buttonStyle(.plain)
      .SmoothUIModule()
      .onHover { hover in
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { isHovered = hover }
        showPopover = hover
      }
      .popover(isPresented: $showPopover, arrowEdge: .bottom) {
        VStack(alignment: .leading, spacing: 12) {
          Text("System Power & Thermal")
            .font(.headline)
            .foregroundColor(Color(hex: colors.textPrimary))
            .padding(.bottom, 4)

          Text("Battery").font(.subheadline).foregroundColor(Color(hex: colors.textSecondary))

          HStack {
            NerdFontIcon("󰌪").foregroundColor(Color(hex: colors.caution)).frame(
              width: 20)
            if battery.isCharging {
              Text("Charging (\(battery.timeToFull)m to full)")
                .foregroundColor(Color(hex: config.chargingColor))
            } else if battery.timeToEmpty > 0 {
              Text("Discharging (\(battery.timeToEmpty)m remaining)")
                .foregroundColor(Color(hex: config.warningColor))
            } else {
              Text("Fully Charged")
                .foregroundColor(Color(hex: colors.textPrimary))
            }
          }
          .font(.system(size: 11, design: .monospaced))

          if let watt = battery.wattInfo {
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Text("Power:").foregroundColor(Color(hex: colors.textSecondary)).frame(
                  width: 70, alignment: .leading)
                Text(String(format: "%.1f W", watt.activeWatts)).foregroundColor(
                  Color(hex: colors.textPrimary))
              }
              HStack {
                Text("Voltage:").foregroundColor(Color(hex: colors.textSecondary)).frame(
                  width: 70, alignment: .leading)
                Text(String(format: "%.1f V", watt.voltage)).foregroundColor(
                  Color(hex: colors.textPrimary))
              }
              HStack {
                Text("Amperage:").foregroundColor(Color(hex: colors.textSecondary)).frame(
                  width: 70, alignment: .leading)
                Text(String(format: "%.0f mA", watt.amperage)).foregroundColor(
                  Color(hex: colors.textPrimary))
              }
            }
            .font(.system(size: 11, design: .monospaced))
            .padding(.leading, 28)
          }

          if let thermal = matrix.data.thermalState {
            Divider().background(Color(hex: colors.surfaceBorder)).padding(.vertical, 4)

            Text("Thermal").font(.subheadline).foregroundColor(Color(hex: colors.textSecondary))

            HStack {
              NerdFontIcon("󰔏").foregroundColor(
                getThermalColor(thermal)
              ).frame(width: 20)
              Text("State:").foregroundColor(Color(hex: colors.textSecondary)).frame(
                width: 70, alignment: .leading)
              Text(thermal).foregroundColor(getThermalColor(thermal))
            }
            .font(.system(size: 11, design: .monospaced))
          }
        }
        .padding()
        .frame(width: 240)
        .background(Color(hex: colors.background))
      }
    }
  }

  private func getThermalColor(_ state: String) -> Color {
    let colors = ConfigManager.shared.currentConfig.colors
    switch state {
    case "Normal": return Color(hex: colors.info)
    case "Warm": return Color(hex: config.warningColor)
    case "Hot", "Critical": return Color(hex: config.dangerColor)
    default: return Color(hex: colors.textPrimary)
    }
  }

}
