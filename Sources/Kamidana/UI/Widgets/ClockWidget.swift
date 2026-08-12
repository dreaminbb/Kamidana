import SwiftUI

struct ClockWidget: View {
    var theme: Theme

    @State private var currentTime = Date()
    let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d (E)"
        return formatter.string(from: currentTime)
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"  // ←時刻フォーマット
        return formatter.string(from: currentTime)
    }
    var body: some View {

        HStack {
            Text(dateText)
            Text(timeText)
        }
        .fontWeight(.bold)
        .foregroundColor(theme.text)
        .SmoothUIModule(theme: theme)
        .onReceive(clockTimer) { input in
            currentTime = input
        }

    }
}
