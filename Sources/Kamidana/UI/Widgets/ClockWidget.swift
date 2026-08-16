import SwiftUI

struct ClockWidget: View {
    var theme: Theme

    @State private var currentTime = Date()
    let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var dateText: String {
        let config = ConfigManager.shared.currentConfig.clock
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: config.locale)
        formatter.dateFormat = config.dateFormat
        return formatter.string(from: currentTime)
    }

    private var timeText: String {
        let config = ConfigManager.shared.currentConfig.clock
        let formatter = DateFormatter()
        formatter.dateFormat = config.timeFormat
        return formatter.string(from: currentTime)
    }
    var body: some View {

        HStack {
            Text(dateText)
            Text(timeText)
        }
        .fontWeight(.bold)
        .foregroundColor(ConfigManager.shared.currentConfig.clock.textColor.resolve(with: theme))
        .SmoothUIModule(theme: theme)
        .onReceive(clockTimer) { input in
            currentTime = input
        }

    }
}
