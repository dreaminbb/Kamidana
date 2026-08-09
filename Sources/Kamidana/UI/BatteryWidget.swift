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
                    Image(systemName: battery.isCharging ? "battery.100.bolt" : "battery.50")
                        .foregroundColor(battery.isCharging ? theme.green : theme.text)
                    
                    if isHovered {
                        Text("\(battery.currentCapacity)%")
                            .foregroundColor(theme.text)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
            .buttonStyle(.plain)
            .SmoothUIModule(theme: theme)
            .onHover { hover in withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { isHovered = hover } }
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("System Power & Thermal")
                        .font(.headline)
                        .foregroundColor(theme.text)
                        .padding(.bottom, 4)
                    
                    Text("Battery").font(.subheadline).foregroundColor(theme.subtext1)
                    
                    HStack {
                        Image(systemName: "bolt.fill").foregroundColor(theme.yellow).frame(width: 20)
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
                    .font(.system(size: 11, design: .monospaced))
                    
                    if let watt = battery.wattInfo {
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
                        .padding(.leading, 28)
                    }
                    
                    if let thermal = matrix.data.thermalState {
                        Divider().background(theme.surface2).padding(.vertical, 4)
                        
                        Text("Thermal").font(.subheadline).foregroundColor(theme.subtext1)
                        
                        HStack {
                            Image(systemName: "thermometer").foregroundColor(getThermalColor(thermal, theme: theme)).frame(width: 20)
                            Text("State:").foregroundColor(theme.subtext1).frame(width: 70, alignment: .leading)
                            Text(thermal).foregroundColor(getThermalColor(thermal, theme: theme))
                        }
                        .font(.system(size: 11, design: .monospaced))
                    }
                }
                .padding()
                .frame(width: 240)
                .background(theme.base)
            }
        }
    }
    
    private func getThermalColor(_ state: String, theme: Theme) -> Color {
        switch state {
        case "Normal": return theme.sapphire
        case "Warm": return theme.yellow
        case "Hot", "Critical": return theme.red
        default: return theme.text
        }
    }
}


