import SwiftUI

struct CompactModeKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var compactMode: Bool {
        get { self[CompactModeKey.self] }
        set { self[CompactModeKey.self] = newValue }
    }
}
