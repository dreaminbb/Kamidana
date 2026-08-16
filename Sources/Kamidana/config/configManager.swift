import Foundation
import SwiftUI

/// Semantic mapping for colors to allow flexible configuration
public enum ThemeColorKey: String, Codable {
  case background, surface, surfaceHighlight, surfaceBorder
  case textPrimary, textSecondary, textTertiary
  case primary, secondary, accent, success, warning, danger, info, caution
  case clear

  public func resolve(with theme: Theme) -> Color {
    switch self {
    case .background: return theme.background
    case .surface: return theme.surface
    case .surfaceHighlight: return theme.surfaceHighlight
    case .surfaceBorder: return theme.surfaceBorder
    case .textPrimary: return theme.textPrimary
    case .textSecondary: return theme.textSecondary
    case .textTertiary: return theme.textTertiary
    case .primary: return theme.primary
    case .secondary: return theme.secondary
    case .accent: return theme.accent
    case .success: return theme.success
    case .warning: return theme.warning
    case .danger: return theme.danger
    case .info: return theme.info
    case .caution: return theme.caution
    case .clear: return .clear
    }
  }
}

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
  public var successColor: ThemeColorKey = .success
  public var cautionColor: ThemeColorKey = .caution
  public var dangerColor: ThemeColorKey = .danger
  public var successThreshold: Float = 30.0
  public var dangerThreshold: Float = 70.0
}

public struct MemoryWidgetConfig: Codable {
  public var icon: String = "󰘚"
  public var iconColor: ThemeColorKey = .secondary
  public var textColor: ThemeColorKey = .secondary
}

public struct DiskWidgetConfig: Codable {
  public var icon: String = "󰋊"
  public var iconColor: ThemeColorKey = .warning
  public var textColor: ThemeColorKey = .warning
  public var readIcon: String = "󰁅"  // arrowDownCircle
  public var writeIcon: String = "󰁝"  // arrowUpCircle
}

public struct NetworkWidgetConfig: Codable {
  public var uploadIcon: String = "󰁝"  // arrowUpRight
  public var downloadIcon: String = "󰁅"  // arrowDownRight
  public var iconColor: ThemeColorKey = .info
  public var textColor: ThemeColorKey = .textPrimary
}

public struct BatteryWidgetConfig: Codable {
  public var chargingColor: ThemeColorKey = .success
  public var dischargingColor: ThemeColorKey = .textPrimary
  public var warningColor: ThemeColorKey = .warning
  public var dangerColor: ThemeColorKey = .danger
}

public struct ClockWidgetConfig: Codable {
  public var dateFormat: String = "M/d (E)"
  public var timeFormat: String = "HH:mm"
  public var locale: String = "ja_JP"
  public var textColor: ThemeColorKey = .textPrimary
}

public struct WifiWidgetConfig: Codable {
  public var connectedIcon: String = "󰤨"
  public var disconnectedIcon: String = "󰤭"
  public var lanIcon: String = "󰲝"
  public var iconColor: ThemeColorKey = .accent
  public var textColor: ThemeColorKey = .textPrimary
  public var disconnectedTextColor: ThemeColorKey = .textTertiary
}

public struct AudioWidgetConfig: Codable {
  public var speakerIcon: String = ""  // speakerWave
  public var speakerMutedIcon: String = "󰟎"  // speakerSlash? Actually speaker is 󰕮
  public var micIcon: String = "󰍬"
  public var micMutedIcon: String = "󰍭"
  public var activeColor: ThemeColorKey = .primary
  public var micActiveColor: ThemeColorKey = .warning
  public var mutedColor: ThemeColorKey = .danger
  public var textColor: ThemeColorKey = .textPrimary
}

public struct SystemControlWidgetConfig: Codable {
  public var icon: String = "󰀵"  // appleLogo
  public var iconColor: ThemeColorKey = .secondary
  public var terminalPath: String = "/opt/homebrew/bin/btop"
}

public struct MusicWidgetConfig: Codable {
  public var defaultIcon: String = "󰝚"
  public var defaultIconColor: ThemeColorKey = .accent
  public var playIcon: String = "󰐊"
  public var pauseIcon: String = "󰏤"
  public var forwardIcon: String = "󰒭"
  public var backwardIcon: String = "󰒮"
}

public struct BluetoothWidgetConfig: Codable {
  public var iconConnected: String = "󰂯"
  public var iconDisconnected: String = "󰂲"
  public var connectedColor: ThemeColorKey = .primary
  public var disconnectedColor: ThemeColorKey = .textTertiary
  public var textColor: ThemeColorKey = .textPrimary
}

// MARK: - Main Config Struct

public struct Config {
  public let UserConfigPath: String = ""
  public let barTopPadding: Int64 = 5
  public let theme: Theme = .catppuccinMocha

  // UI Style
  public var styleNormal: WidgetStyleConfig = .defaultNormal
  public var styleCompact: WidgetStyleConfig = .defaultCompact

  // Widgets
  public var cpu: CpuWidgetConfig = CpuWidgetConfig()
  public var memory: MemoryWidgetConfig = MemoryWidgetConfig()
  public var disk: DiskWidgetConfig = DiskWidgetConfig()
  public var network: NetworkWidgetConfig = NetworkWidgetConfig()
  public var battery: BatteryWidgetConfig = BatteryWidgetConfig()
  public var clock: ClockWidgetConfig = ClockWidgetConfig()
  public var wifi: WifiWidgetConfig = WifiWidgetConfig()
  public var audio: AudioWidgetConfig = AudioWidgetConfig()
  public var systemControl: SystemControlWidgetConfig = SystemControlWidgetConfig()
  public var music: MusicWidgetConfig = MusicWidgetConfig()
  public var bluetooth: BluetoothWidgetConfig = BluetoothWidgetConfig()

  public init() {}
}

// TODO:
// - [ ] define default value
// - [ ] load value from config file
// - [ ] set config to program
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
