import SwiftUI

struct ThermalWidget: View {
    @ObservedObject var matrix: SystemMatrix
    var theme: Theme
    
    var body: some View {
        if let thermal = matrix.data.thermalState {
            HStack(spacing: 4) {
                Image(systemName: "thermometer").foregroundColor(getThermalColor(thermal, theme: theme))
                Text(thermal).foregroundColor(getThermalColor(thermal, theme: theme))
            }
            .hyprlandModule(theme: theme)
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
