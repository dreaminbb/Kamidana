import Foundation
import SwiftUI

enum DisplayModePolicy: String, Codable {
    case auto
    case alwaysCompact
    case alwaysRegular
}

enum WidgetKind: String, CaseIterable, Codable, Hashable {
    case disk
    case gpu
}

final class UISettingsStore: ObservableObject {
    @Published var displayModePolicy: DisplayModePolicy {
        didSet {
            UserDefaults.standard.set(displayModePolicy.rawValue, forKey: Keys.displayModePolicy)
        }
    }

    @Published private(set) var collapsedWidgets: Set<WidgetKind> {
        didSet {
            let values = collapsedWidgets.map(\.rawValue)
            UserDefaults.standard.set(values, forKey: Keys.collapsedWidgets)
        }
    }

    init() {
        let policyRaw = UserDefaults.standard.string(forKey: Keys.displayModePolicy)
        displayModePolicy = DisplayModePolicy(rawValue: policyRaw ?? "") ?? .auto

        if let stored = UserDefaults.standard.stringArray(forKey: Keys.collapsedWidgets) {
            collapsedWidgets = Set(stored.compactMap { WidgetKind(rawValue: $0) })
        } else {
            collapsedWidgets = [.disk, .gpu]
        }
    }

    func isCollapsed(_ kind: WidgetKind, compactMode: Bool) -> Bool {
        compactMode && collapsedWidgets.contains(kind)
    }

    func toggleCollapsed(_ kind: WidgetKind) {
        if collapsedWidgets.contains(kind) {
            collapsedWidgets.remove(kind)
        } else {
            collapsedWidgets.insert(kind)
        }
    }

    func resolveCompactMode(isBuiltInDisplay: Bool) -> Bool {
        switch displayModePolicy {
        case .alwaysCompact:
            return true
        case .alwaysRegular:
            return false
        case .auto:
            return isBuiltInDisplay
        }
    }
}

private enum Keys {
    static let displayModePolicy = "ui.displayModePolicy"
    static let collapsedWidgets = "ui.collapsedWidgets"
}
