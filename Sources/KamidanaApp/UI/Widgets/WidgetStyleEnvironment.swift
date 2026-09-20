import SwiftUI

private struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: Theme? = nil
}

private struct PopupThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: Theme? = nil
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

private struct KamidanaWidgetAnimationKey: EnvironmentKey {
  static let defaultValue = KamidanaMotion.dynamic
}

enum KamidanaPopupHorizontalAlignment {
  case leading
  case center
  case trailing

  var swiftUIAlignment: Alignment {
    switch self {
    case .leading: return .topLeading
    case .center: return .top
    case .trailing: return .topTrailing
    }
  }
}

private struct KamidanaPopupHorizontalAlignmentKey: EnvironmentKey {
  static let defaultValue = KamidanaPopupHorizontalAlignment.center
}

extension EnvironmentValues {
  var theme: Theme? {
    get { self[ThemeEnvironmentKey.self] }
    set { self[ThemeEnvironmentKey.self] = newValue }
  }

  var popupTheme: Theme? {
    get { self[PopupThemeEnvironmentKey.self] }
    set { self[PopupThemeEnvironmentKey.self] = newValue }
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

  var kamidanaWidgetAnimation: KamidanaMotion {
    get { self[KamidanaWidgetAnimationKey.self] }
    set { self[KamidanaWidgetAnimationKey.self] = newValue }
  }

  var kamidanaPopupHorizontalAlignment: KamidanaPopupHorizontalAlignment {
    get { self[KamidanaPopupHorizontalAlignmentKey.self] }
    set { self[KamidanaPopupHorizontalAlignmentKey.self] = newValue }
  }
}

extension View {
  func kamidanaWidgetAnimation(_ animation: KamidanaMotion?) -> some View {
    let resolvedAnimation = animation ?? .dynamic
    return environment(\.kamidanaWidgetAnimation, resolvedAnimation)
      .transaction { transaction in
        if resolvedAnimation == .static {
          transaction.animation = nil
          transaction.disablesAnimations = true
        }
      }
  }
}
