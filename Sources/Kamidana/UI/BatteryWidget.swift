import SwiftUI

struct BatteryWidget: View {
    @ObservedObject var matrix: SystemMatrix
    var theme: Theme
    
    @State private var showPopover = false
    
    var body: some View {
        if let battery = matrix.data.batteryUsage {
            Button(action: { showPopover.toggle() }) {
                HStack(spacing: 6) {
                    // コンパクト表示
                    Image(systemName: battery.isCharging ? "battery.100.bolt" : "battery.50")
                        .foregroundColor(battery.isCharging ? theme.green : theme.text)
                    
                    Text("\(battery.currentCapacity)%")
                        .foregroundColor(theme.text)
                }
            }
            .buttonStyle(.plain)
            .hyprlandModule(theme: theme)
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Battery Information")
                        .font(.headline)
                        .foregroundColor(theme.text)
                        .padding(.bottom, 4)
                    
                    HStack {
                        Image(systemName: "bolt.fill").foregroundColor(theme.yellow)
                        if battery.isCharging {
                            Text("Charging (\(battery.timeToFull)m to full)")
                                .foregroundColor(theme.green)
                        } else if battery.timeToEmpty > 0 {
                            Text("Discharging (\(battery.timeToEmpty)m remaining)")
                                .foregroundColor(theme.peach)
                        } else {
                            Text("Fully Charged")
                                .foregroundColor(theme.text)
                        }
                    }
                    
                    if let watt = battery.wattInfo {
                        Divider().background(theme.surface2)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Power:").foregroundColor(theme.subtext1).frame(width: 70, alignment: .leading)
                                Text(String(format: "%.1f W", watt.activeWatts)).foregroundColor(theme.text)
                            }
                            HStack {
                                Text("Voltage:").foregroundColor(theme.subtext1).frame(width: 70, alignment: .leading)
                                Text(String(format: "%.1f V", watt.voltage)).foregroundColor(theme.text)
                            }
                            HStack {
                                Text("Amperage:").foregroundColor(theme.subtext1).frame(width: 70, alignment: .leading)
                                Text(String(format: "%.0f mA", watt.amperage)).foregroundColor(theme.text)
                            }
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
}

