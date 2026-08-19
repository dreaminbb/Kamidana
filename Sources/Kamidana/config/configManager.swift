import Foundation
import SwiftUI
import Yams

/// Base configuration for widget styling (padding, backgrounds, borders)
public struct WidgetStyleConfig: Codable {
  public var paddingHorizontal: CGFloat
  public var paddingTop: CGFloat
  public var paddingBottom: CGFloat
  public var cornerRadius: CGFloat
  public var backgroundColorOpacity: Double
  public var hoverBackgroundColorOpacity: Double

  public static let defaultNormal = WidgetStyleConfig(
    paddingHorizontal: 12, paddingTop: 6, paddingBottom: 9,
    cornerRadius: 12, backgroundColorOpacity: 0.6, hoverBackgroundColorOpacity: 0.8
  )
  public static let defaultCompact = WidgetStyleConfig(
    paddingHorizontal: 8, paddingTop: 6, paddingBottom: 9,
    cornerRadius: 8, backgroundColorOpacity: 0.6, hoverBackgroundColorOpacity: 0.8
  )
}

// MARK: - Individual Widget Configurations

public struct CpuWidgetConfig: Codable {
  public var icon: String = "󰍛"
  public var successColor: String = "#a6e3a1"
  public var cautionColor: String = "#f9e2af"
  public var dangerColor: String = "#f38ba8"
  public var successThreshold: Float = 30.0
  public var dangerThreshold: Float = 70.0
}

public struct MemoryWidgetConfig: Codable {
  public var icon: String = "󰘚"
  public var iconColor: String = "#cba6f7"
  public var textColor: String = "#cba6f7"
  public var displayFormat: String = "xx %"  // e.g., "x/a" for Used/Total or "xx %" for Percentage
}

public struct DiskWidgetConfig: Codable {
  public var icon: String = "󰋊"
  public var iconColor: String = "#fab387"
  public var textColor: String = "#fab387"
  public var readIcon: String = "󰁅"  // arrowDownCircle
  public var writeIcon: String = "󰁝"  // arrowUpCircle
  public var displayFormat: String = "xx %"  // e.g., "x/a" or "xx %"
}

public struct NetworkWidgetConfig: Codable {
  public var wiredIcon: String = "󰲝"
  public var wirelessIcon: String = "󰤨"
  public var offlineIcon: String = "󰤭"
  public var uploadIcon: String = "󰁝"  // arrowUpRight
  public var downloadIcon: String = "󰁅"  // arrowDownRight
  public var iconColor: String = "#94e2d5"
  public var textColor: String = "#cdd6f4"
}

public struct BatteryWidgetConfig: Codable {
  public var chargingColor: String = "#a6e3a1"
  public var dischargingColor: String = "#cdd6f4"
  public var warningColor: String = "#fab387"
  public var dangerColor: String = "#f38ba8"
  public var charging_right_now: String = "󰂄"
  public var _100_capacity: String = "󰁹"
  public var _90_capacity: String = "󰂂"
  public var _80_capacity: String = "󰂁"
  public var _70_capacity: String = "󰂀"
  public var _60_capacity: String = "󰁿"
  public var _50_capacity: String = "󰁾"
  public var _40_capacity: String = "󰁽"
  public var _30_capacity: String = "󰁼"
  public var _20_capacity: String = "󰁹"
  public var _10_capacity: String = "󰁻"
  public var _sub_10_charged: String = "󰂃"
}

public struct ClockWidgetConfig: Codable {
  public var dateFormat: String = "M/d (E)"
  public var timeFormat: String = "HH:mm"
  public var locale: String = "ja_JP"
  public var textColor: String = "#cdd6f4"
}

public struct AudioWidgetConfig: Codable {
  public var speakerIcon: String = ""  // speakerWave
  public var speakerMutedIcon: String = "󰟎"  // speakerSlash? Actually speaker is 󰕮
  public var micIcon: String = "󰍬"
  public var micMutedIcon: String = "󰍭"
  public var activeColor: String = "#89b4fa"
  public var micActiveColor: String = "#fab387"
  public var mutedColor: String = "#f38ba8"
  public var textColor: String = "#cdd6f4"
  public var inputManagement: Bool? = true
  public var outputManagement: Bool? = true

  public var showsInputManagement: Bool {
    inputManagement != false
  }

  public var showsOutputManagement: Bool {
    outputManagement != false
  }
}

public struct SystemActionWidgetConfig: Codable, Hashable {
  public var action: String  // "sleep", "reboot", "shutdown", "logout", "lockScreen", "aboutThisMac"
  public var name: String?  // Optional label
  public var icon: String
  public var iconColor: String
}

public struct MusicWidgetConfig: Codable {
  public var defaultIcon: String = "󰝚"
  public var defaultIconColor: String = "#f5c2e7"
  public var playIcon: String = "󰐊"
  public var pauseIcon: String = "󰏤"
  public var forwardIcon: String = "󰒭"
  public var backwardIcon: String = "󰒮"
}

public struct TerminalWidgetConfig: Codable, Hashable {
  public var name: String
  public var terminalPath: String
}

public struct GpuWidgetConfig: Codable, Hashable {
  public var icon: String = "󰢮"
}

public struct WidgetInstance: Hashable, Decodable {
  public let id = UUID()
  public let typeID: String
  public let config: AnyHashable
  public let v1Style: KamidanaStyle?
  public let v1Format: String?
  public let v1Activate: KamidanaActivation?

  public init(
    typeID: String,
    config: AnyHashable,
    v1Style: KamidanaStyle? = nil,
    v1Format: String? = nil,
    v1Activate: KamidanaActivation? = nil
  ) {
    self.typeID = typeID
    self.config = config
    self.v1Style = v1Style
    self.v1Format = v1Format
    self.v1Activate = v1Activate
  }

  public static func == (lhs: WidgetInstance, rhs: WidgetInstance) -> Bool {
    lhs.typeID == rhs.typeID && lhs.config == rhs.config && lhs.v1Style == rhs.v1Style
      && lhs.v1Format == rhs.v1Format
      && lhs.v1Activate == rhs.v1Activate
  }
  public func hash(into hasher: inout Hasher) {
    hasher.combine(typeID)
    hasher.combine(config)
    hasher.combine(v1Style)
    hasher.combine(v1Format)
    hasher.combine(v1Activate)
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: DynamicCodingKey.self)
    guard container.allKeys.count == 1, let key = container.allKeys.first else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: decoder.codingPath,
          debugDescription: "Each widget must be a mapping with exactly one widget type key."
        )
      )
    }

    WidgetRegistry.shared.registerAllWidgets()
    guard let factory = WidgetRegistry.shared.factory(for: key.stringValue) else {
      throw DecodingError.dataCorruptedError(
        forKey: key,
        in: container,
        debugDescription: "Unknown widget type '\(key.stringValue)'."
      )
    }

    self.init(
      typeID: key.stringValue,
      config: try factory.decodeConfiguration(from: container.superDecoder(forKey: key))
    )
  }
}

private struct DynamicCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?

  init?(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }
  init?(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
  }
}

public struct WidgetFolderConfig: Hashable, Decodable {
  public var name: String?
  public var icon: String?
  public var iconFolded: String?
  public var iconColor: String = "#cba6f7"
  public var direction: String = "below"  // "below" || "right" || "left"
  public var widgets: [WidgetInstance]

  public init(
    name: String? = nil,
    icon: String? = nil,
    iconFolded: String? = nil,
    iconColor: String = "#cba6f7",
    direction: String = "below",
    widgets: [WidgetInstance]
  ) {
    self.name = name
    self.icon = icon
    self.iconFolded = iconFolded
    self.iconColor = iconColor
    self.direction = direction
    self.widgets = widgets
  }

  private enum CodingKeys: String, CodingKey {
    case name, icon, iconFolded, iconColor, direction, widgets
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      name: try container.decodeIfPresent(String.self, forKey: .name),
      icon: try container.decodeIfPresent(String.self, forKey: .icon),
      iconFolded: try container.decodeIfPresent(String.self, forKey: .iconFolded),
      iconColor: try container.decodeIfPresent(String.self, forKey: .iconColor) ?? "#cba6f7",
      direction: try container.decodeIfPresent(String.self, forKey: .direction) ?? "below",
      widgets: try container.decodeIfPresent([WidgetInstance].self, forKey: .widgets) ?? []
    )
  }
}

// Make all existing configs Hashable so we can use them in ForEach
extension AudioWidgetConfig: Hashable {}
extension MusicWidgetConfig: Hashable {}
extension NetworkWidgetConfig: Hashable {}
extension CpuWidgetConfig: Hashable {}
extension MemoryWidgetConfig: Hashable {}
extension DiskWidgetConfig: Hashable {}
extension BluetoothWidgetConfig: Hashable {}
extension BatteryWidgetConfig: Hashable {}
extension ClockWidgetConfig: Hashable {}

public struct BluetoothWidgetConfig: Codable {
  public var iconConnected: String = "󰂯"
  public var iconDisconnected: String = "󰂲"
  public var connectedColor: String = "#89b4fa"
  public var disconnectedColor: String = "#a6adc8"
  public var textColor: String = "#cdd6f4"
}

// MARK: - Layout Configuration

public struct DisplayLayoutConfig: Decodable {
  public var style: WidgetStyleConfig = WidgetStyleConfig.defaultNormal
  public var left: [WidgetInstance] = []
  public var center: [WidgetInstance] = []
  public var right: [WidgetInstance] = []
}

// MARK: - Main Config Struct

public struct Config: Decodable {
  public let UserConfigPath: String = ""
  public let barTopPadding: Int64 = 5
  public var colors: GlobalColorsConfig = GlobalColorsConfig()

  public var externalDisplay: DisplayLayoutConfig = DisplayLayoutConfig(
    style: .defaultNormal,
    left: [
      WidgetInstance(
        typeID: "widgetFolder",
        config: WidgetFolderConfig(
          name: nil, icon: "󰀵", iconColor: "#cba6f7", direction: "below",
          widgets: [
            WidgetInstance(
              typeID: "systemAction",
              config: SystemActionWidgetConfig(
                action: "aboutThisMac", name: "About this Mac", icon: "󰌢", iconColor: "#94e2d5")),
            WidgetInstance(
              typeID: "systemAction",
              config: SystemActionWidgetConfig(
                action: "sleep", name: "Sleep", icon: "󰒲", iconColor: "#94e2d5")),
            WidgetInstance(
              typeID: "systemAction",
              config: SystemActionWidgetConfig(
                action: "shutdown", name: "Shutdown", icon: "⏻", iconColor: "#f38ba8")),
            WidgetInstance(
              typeID: "systemAction",
              config: SystemActionWidgetConfig(
                action: "reboot", name: "Reboot", icon: "󰑐", iconColor: "#fab387")),
            WidgetInstance(
              typeID: "systemAction",
              config: SystemActionWidgetConfig(
                action: "logout", name: "Logout", icon: "󰈆", iconColor: "#89b4fa")),
            WidgetInstance(
              typeID: "systemAction",
              config: SystemActionWidgetConfig(
                action: "lockScreen", name: "Screen Lock", icon: "󰌾", iconColor: "#f5c2e7")),
          ])),
      WidgetInstance(typeID: "audio", config: AudioWidgetConfig()),
    ],
    center: [
      WidgetInstance(typeID: "music", config: MusicWidgetConfig()),
      WidgetInstance(
        typeID: "terminal",
        config: TerminalWidgetConfig(name: "btop", terminalPath: "/opt/homebrew/bin/btop")),
    ],
    right: [
      WidgetInstance(typeID: "network", config: NetworkWidgetConfig()),
      WidgetInstance(typeID: "cpu", config: CpuWidgetConfig()),
      WidgetInstance(typeID: "memory", config: MemoryWidgetConfig()),
      WidgetInstance(typeID: "disk", config: DiskWidgetConfig()),
      WidgetInstance(typeID: "bluetooth", config: BluetoothWidgetConfig()),
      WidgetInstance(typeID: "battery", config: BatteryWidgetConfig()),
      WidgetInstance(typeID: "clock", config: ClockWidgetConfig()),
    ]
  )

  public var builtInDisplay: DisplayLayoutConfig = DisplayLayoutConfig(
    style: .defaultCompact,
    left: [
      WidgetInstance(
        typeID: "widgetFolder",
        config: WidgetFolderConfig(
          name: nil, icon: "󰀵", iconColor: "#cba6f7", direction: "below",
          widgets: [
            WidgetInstance(
              typeID: "systemAction",
              config: SystemActionWidgetConfig(
                action: "aboutThisMac", name: "About this Mac", icon: "󰌢", iconColor: "#94e2d5")),
            WidgetInstance(
              typeID: "systemAction",
              config: SystemActionWidgetConfig(
                action: "sleep", name: "Sleep", icon: "󰒲", iconColor: "#94e2d5")),
            WidgetInstance(
              typeID: "systemAction",
              config: SystemActionWidgetConfig(
                action: "shutdown", name: "Shutdown", icon: "⏻", iconColor: "#f38ba8")),
            WidgetInstance(
              typeID: "systemAction",
              config: SystemActionWidgetConfig(
                action: "reboot", name: "Reboot", icon: "󰑐", iconColor: "#fab387")),
            WidgetInstance(
              typeID: "systemAction",
              config: SystemActionWidgetConfig(
                action: "logout", name: "Logout", icon: "󰈆", iconColor: "#89b4fa")),
            WidgetInstance(
              typeID: "systemAction",
              config: SystemActionWidgetConfig(
                action: "lockScreen", name: "Screen Lock", icon: "󰌾", iconColor: "#f5c2e7")),
          ])),
      WidgetInstance(typeID: "audio", config: AudioWidgetConfig()),
    ],
    center: [
      WidgetInstance(typeID: "music", config: MusicWidgetConfig()),
      WidgetInstance(
        typeID: "terminal",
        config: TerminalWidgetConfig(name: "btop", terminalPath: "/opt/homebrew/bin/btop")),
    ],
    right: [
      WidgetInstance(typeID: "cpu", config: CpuWidgetConfig()),
      WidgetInstance(typeID: "memory", config: MemoryWidgetConfig()),
      WidgetInstance(
        typeID: "widgetFolder",
        config:
          WidgetFolderConfig(
            name: "", icon: "󰇙", iconFolded: "", iconColor: "#cba6f7", direction: "left",
            widgets: [
              WidgetInstance(typeID: "network", config: NetworkWidgetConfig()),
              WidgetInstance(typeID: "disk", config: DiskWidgetConfig()),
            ])),
      WidgetInstance(typeID: "bluetooth", config: BluetoothWidgetConfig()),
      WidgetInstance(typeID: "battery", config: BatteryWidgetConfig()),
      WidgetInstance(typeID: "clock", config: ClockWidgetConfig()),
    ]
  )

  public init() {}

  private enum CodingKeys: String, CodingKey {
    case colors, externalDisplay, builtInDisplay
  }

  public init(from decoder: Decoder) throws {
    let defaults = Config()
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init()
    colors =
      try container.decodeIfPresent(GlobalColorsConfig.self, forKey: .colors) ?? defaults.colors
    externalDisplay =
      try container.decodeIfPresent(DisplayLayoutConfig.self, forKey: .externalDisplay)
      ?? defaults.externalDisplay
    builtInDisplay =
      try container.decodeIfPresent(DisplayLayoutConfig.self, forKey: .builtInDisplay)
      ?? defaults.builtInDisplay
  }
}

public struct GlobalColorsConfig: Codable {
  // Backgrounds & Surfaces
  public var background: String = "#1e1e2e"
  public var surface: String = "#313244"
  public var surfaceHighlight: String = "#45475a"
  public var surfaceBorder: String = "#585b70"

  // Typography
  public var textPrimary: String = "#cdd6f4"
  public var textSecondary: String = "#bac2de"
  public var textTertiary: String = "#a6adc8"

  // Semantic Colors (Global)
  public var primary: String = "#89b4fa"
  public var secondary: String = "#cba6f7"
  public var accent: String = "#f5c2e7"
  public var success: String = "#a6e3a1"
  public var warning: String = "#fab387"
  public var danger: String = "#f38ba8"
  public var info: String = "#94e2d5"
  public var caution: String = "#f9e2af"
}

// Extension to convert hexadecimal color codes to SwiftUI Color
extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let a: UInt64
    let r: UInt64
    let g: UInt64
    let b: UInt64
    switch hex.count {
    case 3:  // RGB (12-bit)
      (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6:  // RGB (24-bit)
      (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8:  // ARGB (32-bit)
      (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default:
      (a, r, g, b) = (255, 0, 0, 0)
    }
    self.init(
      .sRGB,
      red: Double(r) / 255,
      green: Double(g) / 255,
      blue: Double(b) / 255,
      opacity: Double(a) / 255
    )
  }
}

public class ConfigManager {

  public static let shared = ConfigManager()
  public var currentConfig = Config()
  public private(set) var currentV1Config: KamidanaConfigurationV1?

  public static let MAIN_CONFIG_FILE_NAME = "config.yaml"
  public static let CONFIG_PARENT_DIR_NAME = ".config"
  public static let CONFIG_DIR_NAME = "kamidana"

  public init(shouldLoadUserConfiguration: Bool = true) {
    if shouldLoadUserConfiguration {
      loadConfig()
    }
  }

  public func loadConfig() {
    let url = resolveConfigFileURL()
    print("[LOG] CONFIG PATH URL: \(url)")

    guard FileManager.default.fileExists(atPath: url.path) else {
      print("Config file not found at \(url.path), using defaults")
      return
    }
    do {
      let yamlData = try String(contentsOf: url, encoding: .utf8)
      try applyV1Configuration(yaml: yamlData)
      print("[LOG] Successfully loaded v1 config from YAML. path \(url.path)")
    } catch {
      print("Failed to decode v1 config \(error)")
    }
  }

  public func applyV1Configuration(yaml: String) throws {
    let decoded = try KamidanaConfigurationV1Decoder.decode(yaml: yaml)
    let runtimeConfig = KamidanaConfigurationV1Adapter.makeLegacyConfig(from: decoded)
    currentV1Config = decoded
    currentConfig = runtimeConfig
  }

  /// Resolves the fixed configuration directory: ~/.config/kamidana/
  public func resolveConfigDirectory(
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
  ) -> URL {
    return
      homeDirectory
      .appendingPathComponent(Self.CONFIG_PARENT_DIR_NAME)
      .appendingPathComponent(Self.CONFIG_DIR_NAME)
  }

  /// Resolves the fixed configuration file URL: ~/.config/kamidana/config.yaml
  public func resolveConfigFileURL(
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
  ) -> URL {
    return resolveConfigDirectory(homeDirectory: homeDirectory)
      .appendingPathComponent(Self.MAIN_CONFIG_FILE_NAME)
  }

  /// Returns the path string of the user's config directory (~/.config/kamidana)
  public func fetchUserConfigPath() -> String {
    return resolveConfigDirectory().path
  }

}
