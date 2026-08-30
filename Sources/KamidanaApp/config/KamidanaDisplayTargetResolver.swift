import Foundation

/// The display data needed to resolve status-bar placement without AppKit.
public struct KamidanaDisplayTargetScreen: Equatable {
  public var id: UInt32
  public var name: String
  public var isBuiltIn: Bool
  public var isPrimary: Bool

  public init(id: UInt32, name: String, isBuiltIn: Bool, isPrimary: Bool) {
    self.id = id
    self.name = name
    self.isBuiltIn = isBuiltIn
    self.isPrimary = isPrimary
  }
}

/// Resolves display selectors as a union while retaining the supplied screen order.
public enum KamidanaDisplayTargetResolver {
  public static func resolve(
    targets: [KamidanaDisplayTarget],
    screens: [KamidanaDisplayTargetScreen]
  ) -> [KamidanaDisplayTargetScreen] {
    var selectedIDs = Set<UInt32>()

    for target in targets {
      for screen in screens where matches(target, screen: screen) {
        selectedIDs.insert(screen.id)
      }
    }

    var resolvedIDs = Set<UInt32>()
    return screens.filter { screen in
      selectedIDs.contains(screen.id) && resolvedIDs.insert(screen.id).inserted
    }
  }

  private static func matches(
    _ target: KamidanaDisplayTarget,
    screen: KamidanaDisplayTargetScreen
  ) -> Bool {
    switch target.kind {
    case .primary:
      return screen.isPrimary
    case .secondary:
      return !screen.isPrimary
    case .builtIn:
      return screen.isBuiltIn
    case .external:
      return !screen.isBuiltIn
    case .all:
      return true
    case .name:
      return screen.name == target.name
    case .id:
      return screen.id == target.id
    }
  }
}
