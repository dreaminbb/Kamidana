import SwiftUI

struct BatteryWidget: View {
    @ObservedObject var matrix: SystemMatrix
    var theme: Theme

    @State private var showPopover = false
    @State private var isHovered = false

    var body: some View {
        let config = ConfigManager.shared.currentConfig.battery
        if let battery = matrix.data.batteryUsage {
            Button(action: { showPopover.toggle() }) {
                HStack(spacing: 6) {
                    // Compact display
                    NerdFontIcon(
                        batteryIconName(
                            capacity: battery.currentCapacity, isCharging: battery.isCharging)
                    )
                    .foregroundColor(battery.isCharging ? config.chargingColor.resolve(with: theme) : config.dischargingColor.resolve(with: theme))

                    Text("\(battery.currentCapacity)%")
                        .foregroundColor(config.dischargingColor.resolve(with: theme))
                }
            }
            .buttonStyle(.plain)
            .SmoothUIModule(theme: theme)
            .onHover { hover in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { isHovered = hover }
                showPopover = hover
            }
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("System Power & Thermal")
                        .font(.headline)
                        .foregroundColor(theme.textPrimary)
                        .padding(.bottom, 4)

                    Text("Battery").font(.subheadline).foregroundColor(theme.textSecondary)

                    HStack {
                        NerdFontIcon("󰌪").foregroundColor(theme.caution).frame(
                            width: 20)
                        if battery.isCharging {
                            Text("Charging (\(battery.timeToFull)m to full)")
                                .foregroundColor(config.chargingColor.resolve(with: theme))
                        } else if battery.timeToEmpty > 0 {
                            Text("Discharging (\(battery.timeToEmpty)m remaining)")
                                .foregroundColor(config.warningColor.resolve(with: theme))
                        } else {
                            Text("Fully Charged")
                                .foregroundColor(theme.textPrimary)
                        }
                    }
                    .font(.system(size: 11, design: .monospaced))

                    if let watt = battery.wattInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Power:").foregroundColor(theme.textSecondary).frame(
                                    width: 70, alignment: .leading)
                                Text(String(format: "%.1f W", watt.activeWatts)).foregroundColor(
                                    theme.textPrimary)
                            }
                            HStack {
                                Text("Voltage:").foregroundColor(theme.textSecondary).frame(
                                    width: 70, alignment: .leading)
                                Text(String(format: "%.1f V", watt.voltage)).foregroundColor(
                                    theme.textPrimary)
                            }
                            HStack {
                                Text("Amperage:").foregroundColor(theme.textSecondary).frame(
                                    width: 70, alignment: .leading)
                                Text(String(format: "%.0f mA", watt.amperage)).foregroundColor(
                                    theme.textPrimary)
                            }
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.leading, 28)
                    }

                    if let thermal = matrix.data.thermalState {
                        Divider().background(theme.surfaceBorder).padding(.vertical, 4)

                        Text("Thermal").font(.subheadline).foregroundColor(theme.textSecondary)

                        HStack {
                            NerdFontIcon("󰔏").foregroundColor(
                                getThermalColor(thermal, theme: theme)
                            ).frame(width: 20)
                            Text("State:").foregroundColor(theme.textSecondary).frame(
                                width: 70, alignment: .leading)
                            Text(thermal).foregroundColor(getThermalColor(thermal, theme: theme))
                        }
                        .font(.system(size: 11, design: .monospaced))
                    }
                }
                .padding()
                .frame(width: 240)
                .background(theme.background)
            }
        }
    }

    private func getThermalColor(_ state: String, theme: Theme) -> Color {
        let config = ConfigManager.shared.currentConfig.battery
        switch state {
        case "Normal": return theme.info
        case "Warm": return config.warningColor.resolve(with: theme)
        case "Hot", "Critical": return config.dangerColor.resolve(with: theme)
        default: return theme.textPrimary
        }
    }

    private func batteryIconName(capacity: Int64, isCharging: Bool) -> String {
        if isCharging {
            return ""
        }
        switch capacity {
        case ..<13: return ""
        case ..<38: return ""
        case ..<63: return ""
        case ..<88: return ""
        default: return ""
        }
    }
}
