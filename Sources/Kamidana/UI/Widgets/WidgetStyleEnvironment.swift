import SwiftUI

struct WidgetStyleKey: EnvironmentKey {
    static let defaultValue: WidgetStyleConfig = .defaultNormal
}

extension EnvironmentValues {
    var widgetStyle: WidgetStyleConfig {
        get { self[WidgetStyleKey.self] }
        set { self[WidgetStyleKey.self] = newValue }
    }
}
