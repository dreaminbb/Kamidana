import Foundation
import SwiftUI

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

public struct WifiWidgetConfig: Codable {
  public var connectedIcon: String = "󰤨"
  public var disconnectedIcon: String = "󰤭"
  public var lanIcon: String = "󰲝"
  public var iconColor: String = "#f5c2e7"
  public var textColor: String = "#cdd6f4"
  public var disconnectedTextColor: String = "#a6adc8"
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
}

public struct SystemControlWidgetConfig: Codable {
  public var icon: String = "󰀵"  // appleLogo
  public var iconColor: String = "#cba6f7"
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

public struct FolderWidgetConfig: Codable, Hashable {
  public var name: String
  public var icon: String
  public var widgets: [AnyWidgetConfig]
}

// Make all existing configs Hashable so we can use them in ForEach
extension SystemControlWidgetConfig: Hashable {}
extension WifiWidgetConfig: Hashable {}
extension AudioWidgetConfig: Hashable {}
extension MusicWidgetConfig: Hashable {}
extension NetworkWidgetConfig: Hashable {}
extension CpuWidgetConfig: Hashable {}
extension MemoryWidgetConfig: Hashable {}
extension DiskWidgetConfig: Hashable {}
extension BluetoothWidgetConfig: Hashable {}
extension BatteryWidgetConfig: Hashable {}
extension ClockWidgetConfig: Hashable {}

// MARK: - Heterogeneous Widget Enum

public enum AnyWidgetConfig: Codable, Hashable {
  case systemControl(SystemControlWidgetConfig)
  case wifi(WifiWidgetConfig)
  case audio(AudioWidgetConfig)
  case music(MusicWidgetConfig)
  case terminal(TerminalWidgetConfig)
  case network(NetworkWidgetConfig)
  case cpu(CpuWidgetConfig)
  case memory(MemoryWidgetConfig)
  case disk(DiskWidgetConfig)
  case bluetooth(BluetoothWidgetConfig)
  case battery(BatteryWidgetConfig)
  case clock(ClockWidgetConfig)
  case folder(FolderWidgetConfig)

  private enum CodingKeys: String, CodingKey {
    case systemControl, wifi, audio, music, terminal, network, cpu, memory, disk, bluetooth,
      battery, clock, folder
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let config = try container.decodeIfPresent(
      SystemControlWidgetConfig.self, forKey: .systemControl)
    {
      self = .systemControl(config)
    } else if let config = try container.decodeIfPresent(WifiWidgetConfig.self, forKey: .wifi) {
      self = .wifi(config)
    } else if let config = try container.decodeIfPresent(AudioWidgetConfig.self, forKey: .audio) {
      self = .audio(config)
    } else if let config = try container.decodeIfPresent(MusicWidgetConfig.self, forKey: .music) {
      self = .music(config)
    } else if let config = try container.decodeIfPresent(
      TerminalWidgetConfig.self, forKey: .terminal)
    {
      self = .terminal(config)
    } else if let config = try container.decodeIfPresent(NetworkWidgetConfig.self, forKey: .network)
    {
      self = .network(config)
    } else if let config = try container.decodeIfPresent(CpuWidgetConfig.self, forKey: .cpu) {
      self = .cpu(config)
    } else if let config = try container.decodeIfPresent(MemoryWidgetConfig.self, forKey: .memory) {
      self = .memory(config)
    } else if let config = try container.decodeIfPresent(DiskWidgetConfig.self, forKey: .disk) {
      self = .disk(config)
    } else if let config = try container.decodeIfPresent(
      BluetoothWidgetConfig.self, forKey: .bluetooth)
    {
      self = .bluetooth(config)
    } else if let config = try container.decodeIfPresent(BatteryWidgetConfig.self, forKey: .battery)
    {
      self = .battery(config)
    } else if let config = try container.decodeIfPresent(ClockWidgetConfig.self, forKey: .clock) {
      self = .clock(config)
    } else if let config = try container.decodeIfPresent(FolderWidgetConfig.self, forKey: .folder) {
      self = .folder(config)
    } else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: decoder.codingPath, debugDescription: "Unknown widget type"))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .systemControl(let config): try container.encode(config, forKey: .systemControl)
    case .wifi(let config): try container.encode(config, forKey: .wifi)
    case .audio(let config): try container.encode(config, forKey: .audio)
    case .music(let config): try container.encode(config, forKey: .music)
    case .terminal(let config): try container.encode(config, forKey: .terminal)
    case .network(let config): try container.encode(config, forKey: .network)
    case .cpu(let config): try container.encode(config, forKey: .cpu)
    case .memory(let config): try container.encode(config, forKey: .memory)
    case .disk(let config): try container.encode(config, forKey: .disk)
    case .bluetooth(let config): try container.encode(config, forKey: .bluetooth)
    case .battery(let config): try container.encode(config, forKey: .battery)
    case .clock(let config): try container.encode(config, forKey: .clock)
    case .folder(let config): try container.encode(config, forKey: .folder)
    }
  }
}

public struct BluetoothWidgetConfig: Codable {
  public var iconConnected: String = "󰂯"
  public var iconDisconnected: String = "󰂲"
  public var connectedColor: String = "#89b4fa"
  public var disconnectedColor: String = "#a6adc8"
  public var textColor: String = "#cdd6f4"
}

// MARK: - Main Config Struct

public struct Config {
  public let UserConfigPath: String = ""
  public let barTopPadding: Int64 = 5
  public var colors: GlobalColorsConfig = GlobalColorsConfig()

  // UI Style
  public var styleNormal: WidgetStyleConfig = .defaultNormal
  public var styleCompact: WidgetStyleConfig = .defaultCompact

  // Layout Sections
  public var left: [AnyWidgetConfig] = [
    .systemControl(SystemControlWidgetConfig()),
    .wifi(WifiWidgetConfig()),
    .audio(AudioWidgetConfig()),
  ]

  public var center: [AnyWidgetConfig] = [
    .music(MusicWidgetConfig()),
    .terminal(TerminalWidgetConfig(name: "btop", terminalPath: "/opt/homebrew/bin/htop")),
  ]

  public var right: [AnyWidgetConfig] = [
    .network(NetworkWidgetConfig()),
    .cpu(CpuWidgetConfig()),
    .memory(MemoryWidgetConfig()),
    .disk(DiskWidgetConfig()),
    .bluetooth(BluetoothWidgetConfig()),
    .battery(BatteryWidgetConfig()),
    .clock(ClockWidgetConfig()),
  ]

  public init() {}
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

// TODO:
// - [x] define default value
// - [ ] load value from config file
// - [ ] set config to program / (half done)
public class ConfigManager {

  public static let shared = ConfigManager()
  public var currentConfig = Config()

  public static let MAIN_CONFIG_FILE_NAME = "config.yaml"
  public static let CONFIG_PARENT_DIR_NAME = ".config"
  public static let CONFIG_DIR_NAME = "kamidana"

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
