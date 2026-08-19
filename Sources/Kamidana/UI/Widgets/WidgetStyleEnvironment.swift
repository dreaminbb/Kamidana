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

private struct KamidanaV1StyleKey: EnvironmentKey {
  static let defaultValue: KamidanaStyle? = nil
}

private struct KamidanaWidgetSurfaceVisibilityKey: EnvironmentKey {
  static let defaultValue = true
}

private struct KamidanaWidgetFormatKey: EnvironmentKey {
  static let defaultValue: String? = nil
}

private struct KamidanaWidgetActivationKey: EnvironmentKey {
  static let defaultValue: KamidanaActivation? = nil
}

extension EnvironmentValues {
  var kamidanaV1Style: KamidanaStyle? {
    get { self[KamidanaV1StyleKey.self] }
    set { self[KamidanaV1StyleKey.self] = newValue }
  }

  var showsKamidanaWidgetSurface: Bool {
    get { self[KamidanaWidgetSurfaceVisibilityKey.self] }
    set { self[KamidanaWidgetSurfaceVisibilityKey.self] = newValue }
  }

  var kamidanaWidgetFormat: String? {
    get { self[KamidanaWidgetFormatKey.self] }
    set { self[KamidanaWidgetFormatKey.self] = newValue }
  }

  var kamidanaWidgetActivation: KamidanaActivation? {
    get { self[KamidanaWidgetActivationKey.self] }
    set { self[KamidanaWidgetActivationKey.self] = newValue }
  }
}
