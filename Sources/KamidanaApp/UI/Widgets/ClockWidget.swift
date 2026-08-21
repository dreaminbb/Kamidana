import SwiftUI

struct ClockWidget: View {
    @Environment(\.kamidanaV1Style) private var v1Style
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
            iconColor: Color(hex: v1Style?.iconColor ?? config.textColor),
            textColor: Color(hex: v1Style?.color ?? config.textColor)
        )
        .fontWeight(.bold)
        .SmoothUIModule()
        .onReceive(clockTimer) { input in
            currentTime = input
        }

    }
}
