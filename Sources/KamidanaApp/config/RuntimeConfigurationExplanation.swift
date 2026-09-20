import Foundation

public extension Notification.Name {
  static let kamidanaRuntimeExplanationRequest = Notification.Name(
    "com.shin.Kamidana.runtimeExplanationRequest"
  )
}

public struct KamidanaRuntimeConfiguration: Codable, Equatable {
  public let schemaVersion: Int
  public let pid: Int32
  public let process: String
  public let generatedAt: String
  public let requestID: String?
  public let configPath: String
  public let source: String
  public let displays: [String: KamidanaRuntimeDisplay]
  public let activeScreens: [KamidanaRuntimeScreen]

  public init(
    pid: Int32,
    process: String,
    generatedAt: String,
    requestID: String? = nil,
    configPath: String,
    source: String,
    displays: [String: KamidanaRuntimeDisplay],
    activeScreens: [KamidanaRuntimeScreen]
  ) {
    self.schemaVersion = 1
    self.pid = pid
    self.process = process
    self.generatedAt = generatedAt
    self.requestID = requestID
    self.configPath = configPath
    self.source = source
    self.displays = displays
    self.activeScreens = activeScreens
  }

  private enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case pid
    case process
    case generatedAt = "generated_at"
    case requestID = "request_id"
    case configPath = "config_path"
    case source
    case displays
    case activeScreens = "active_screens"
  }
}

public struct KamidanaRuntimeDisplay: Codable, Equatable {
  public let centerDefault: String
  public let left: KamidanaRuntimeSection
  public let center: KamidanaRuntimeSection
  public let right: KamidanaRuntimeSection

  public init(
    centerDefault: String,
    left: KamidanaRuntimeSection,
    center: KamidanaRuntimeSection,
    right: KamidanaRuntimeSection
  ) {
    self.centerDefault = centerDefault
    self.left = left
    self.center = center
    self.right = right
  }

  private enum CodingKeys: String, CodingKey {
    case centerDefault = "center_default"
    case left
    case center
    case right
  }
}

public struct KamidanaRuntimeSection: Codable, Equatable {
  public let activation: KamidanaActivation?
  public let animation: KamidanaMotion?
  public let widgets: [KamidanaRuntimeWidget]

  public init(
    activation: KamidanaActivation?,
    animation: KamidanaMotion? = nil,
    widgets: [KamidanaRuntimeWidget]
  ) {
    self.activation = activation
    self.animation = animation
    self.widgets = widgets
  }
}

public struct KamidanaRuntimeWidget: Codable, Equatable {
  public let id: String
  public let type: String
  public let path: String
  public let activation: KamidanaActivation
  public let activationSource: String
  public let animation: KamidanaMotion
  public let style: KamidanaStyle
  public let popupStyle: KamidanaStyle
  public let action: String?
  public let format: String?
  public let icon: String?
  public let children: [KamidanaRuntimeWidget]

  public init(
    id: String,
    type: String,
    path: String,
    activation: KamidanaActivation,
    activationSource: String,
    animation: KamidanaMotion,
    style: KamidanaStyle,
    popupStyle: KamidanaStyle,
    action: String? = nil,
    format: String? = nil,
    icon: String? = nil,
    children: [KamidanaRuntimeWidget] = []
  ) {
    self.id = id
    self.type = type
    self.path = path
    self.activation = activation
    self.activationSource = activationSource
    self.animation = animation
    self.style = style
    self.popupStyle = popupStyle
    self.action = action
    self.format = format
    self.icon = icon
    self.children = children
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case type
    case path
    case activation
    case activationSource = "activation_source"
    case animation
    case style
    case popupStyle = "popup_style"
    case action
    case format
    case icon
    case children
  }
}

public struct KamidanaRuntimeScreen: Codable, Equatable {
  public let name: String
  public let displayID: UInt32?
  public let isBuiltIn: Bool
  public let profile: String?

  public init(name: String, displayID: UInt32?, isBuiltIn: Bool, profile: String?) {
    self.name = name
    self.displayID = displayID
    self.isBuiltIn = isBuiltIn
    self.profile = profile
  }

  private enum CodingKeys: String, CodingKey {
    case name
    case displayID = "display_id"
    case isBuiltIn = "is_built_in"
    case profile
  }
}
