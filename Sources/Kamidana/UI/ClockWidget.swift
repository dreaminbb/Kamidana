import SwiftUI

struct ClockWidget: View {
    var theme: Theme
    @State private var currentTime = Date()
    let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(currentTime, style: .time)
            .fontWeight(.bold)
            .foregroundColor(theme.text)
            .SmoothUIModule(theme: theme)
            .onReceive(clockTimer) { input in
                currentTime = input
            }
    }
}
