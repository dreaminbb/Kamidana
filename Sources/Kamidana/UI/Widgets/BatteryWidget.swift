import SwiftUI

struct BatteryWidget: View {
    @ObservedObject var matrix: SystemMatrix
    var theme: Theme

    @State private var showPopover = false
    @State private var isHovered = false

    var body: some View {
        if let battery = matrix.data.batteryUsage {
            Button(action: { showPopover.toggle() }) {
                HStack(spacing: 6) {
                    // コンパクト表示
                    Image(
                        systemName: batteryIconName(
                            capacity: battery.currentCapacity, isCharging: battery.isCharging)
                    )
                    .foregroundColor(battery.isCharging ? theme.success : theme.textPrimary)

                    Text("\(battery.currentCapacity)%")
                        .foregroundColor(theme.textPrimary)
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
                        Image(systemName: "bolt.fill").foregroundColor(theme.caution).frame(
                            width: 20)
                        if battery.isCharging {
                            Text("Charging (\(battery.timeToFull)m to full)")
                                .foregroundColor(theme.success)
                        } else if battery.timeToEmpty > 0 {
                            Text("Discharging (\(battery.timeToEmpty)m remaining)")
                                .foregroundColor(theme.warning)
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
                            Image(systemName: "thermometer").foregroundColor(
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
        switch state {
        case "Normal": return theme.info
        case "Warm": return theme.caution
        case "Hot", "Critical": return theme.danger
        default: return theme.textPrimary
        }
    }

    private func batteryIconName(capacity: Int64, isCharging: Bool) -> String {
        let level: String
        print("capacity: \(capacity)  is charging \(isCharging)")
        switch (capacity, isCharging) {
        case (..<13, _): level = "0"
        case (..<38, _): level = "25"
        case (..<63, _): level = "50"
        case (..<88, _): level = "75"
        case (100, true): level = "100percent"
        default: level = "100"
        }

        return isCharging ? "battery.\(level).bolt" : "battery.\(level)"
    }
}
