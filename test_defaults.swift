import Foundation
let defaults = UserDefaults.standard
print("ui.displayModePolicy:", defaults.string(forKey: "ui.displayModePolicy") ?? "nil")
