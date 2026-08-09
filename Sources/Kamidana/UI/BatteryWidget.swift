import SwiftUI

struct BatteryWidget: View {
    @ObservedObject var matrix: SystemMatrix
    var theme: Theme
    
    @State private var isHovered = false
    
    var body: some View {
        if let battery = matrix.data.batteryUsage {
            HStack(spacing: 6) {
                // コンパクト表示
                Image(systemName: battery.isCharging ? "battery.100.bolt" : "battery.50")
                    .foregroundColor(battery.isCharging ? theme.green : theme.text)
                
                Text("\(battery.currentCapacity)%")
                    .foregroundColor(theme.text)
                
                // ホバー時展開
                if isHovered {
                    Divider().frame(height: 16).background(theme.surface2)
                    
                    HStack(spacing: 8) {
                        if battery.isCharging {
                            Text("完了まで: \(battery.timeToFull)m").foregroundColor(theme.green)
                        } else if battery.timeToEmpty > 0 {
                            Text("残り: \(battery.timeToEmpty)m").foregroundColor(theme.peach)
                        }
                        
                        if let watt = battery.wattInfo {
                            Text(String(format: "%.1fW", watt.activeWatts))
                                .foregroundColor(theme.text)
                        }
                    }
                    .font(.system(size: 10))
                }
            }
            .hyprlandModule(theme: theme)
            .onHover { hover in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isHovered = hover
                }
            }
        }
    }
}
