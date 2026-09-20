import SwiftUI

struct ClockWidget: View {
    @Environment(\.theme) private var theme
    @Environment(\.kamidanaWidgetFormat) private var widgetFormat
    let config: ClockWidgetConfig
    @State private var currentTime = Date()
    let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: config.locale)
        formatter.dateFormat = config.dateFormat
        return formatter.string(from: currentTime)
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = config.timeFormat
        return formatter.string(from: currentTime)
    }
    var body: some View {

        FormattedWidgetLabel(
            format: widgetFormat ?? "{date} {time}",
            values: ["date": dateText, "time": timeText],
            iconColor: theme?.iconForeground ?? Color(hex: config.textColor),
            textColor: theme?.foreground ?? Color(hex: config.textColor)
        )
        .fontWeight(.bold)
        .SmoothUIModule(theme: theme)
        .onReceive(clockTimer) { input in
            currentTime = input
        }

    }
}
