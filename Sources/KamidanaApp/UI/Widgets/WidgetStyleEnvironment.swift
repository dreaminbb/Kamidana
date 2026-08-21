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

private struct KamidanaPopupStyleKey: EnvironmentKey {
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

private struct KamidanaWidgetMotionKey: EnvironmentKey {
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
  var kamidanaV1Style: KamidanaStyle? {
    get { self[KamidanaV1StyleKey.self] }
    set { self[KamidanaV1StyleKey.self] = newValue }
  }

  var kamidanaPopupStyle: KamidanaStyle? {
    get { self[KamidanaPopupStyleKey.self] }
    set { self[KamidanaPopupStyleKey.self] = newValue }
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

  var kamidanaWidgetMotion: KamidanaMotion {
    get { self[KamidanaWidgetMotionKey.self] }
    set { self[KamidanaWidgetMotionKey.self] = newValue }
  }


  var kamidanaPopupHorizontalAlignment: KamidanaPopupHorizontalAlignment {
    get { self[KamidanaPopupHorizontalAlignmentKey.self] }
    set { self[KamidanaPopupHorizontalAlignmentKey.self] = newValue }
  }
}

extension View {
  func kamidanaWidgetMotion(_ motion: KamidanaMotion?) -> some View {
    let resolvedMotion = motion ?? .dynamic
    return environment(\.kamidanaWidgetMotion, resolvedMotion)
      .transaction { transaction in
        if resolvedMotion == .static {
          transaction.animation = nil
          transaction.disablesAnimations = true
        }
      }
  }
}
