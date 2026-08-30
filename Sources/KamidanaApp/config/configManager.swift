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

public enum MusicWidgetPlacement: String, Codable, Hashable {
    case standalone
    case center
}

public struct MusicWidgetConfig: Codable {
    public var defaultIcon: String = "󰝚"
    public var defaultIconColor: String = "#f5c2e7"
    public var playIcon: String = "󰐊"
    public var pauseIcon: String = "󰏤"
    public var forwardIcon: String = "󰒭"
    public var backwardIcon: String = "󰒮"
    public var normalFormat: String = "{artwork} {title}"
    public var formatOnAction: String = "{artwork} {slider}"
    public var actionMetadataFormat: String? = "{title} - {album}"
    public var sliderChangeColor: String? = nil
    public var sliderPauseColor: String? = nil
    public var sliderBarColor: String? = nil
    public var extend: KamidanaMusicExtendDirection = .right
    public var artworkSpinDuration: Double = 3
    public var actionArtworkSpinDuration: Double = 3
    public var placement: MusicWidgetPlacement = .standalone
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
    public let v1PopupStyle: KamidanaStyle?
    public let v1Format: String?
    public let v1Activate: KamidanaActivation?
    public let v1Motion: KamidanaMotion?

    public init(
        typeID: String,
        config: AnyHashable,
        v1Style: KamidanaStyle? = nil,
        v1PopupStyle: KamidanaStyle? = nil,
        v1Format: String? = nil,
        v1Activate: KamidanaActivation? = nil,
        v1Motion: KamidanaMotion? = nil
    ) {
        self.typeID = typeID
        self.config = config
        self.v1Style = v1Style
        self.v1PopupStyle = v1PopupStyle
        self.v1Format = v1Format
        self.v1Activate = v1Activate
        self.v1Motion = v1Motion
    }

    public static func == (lhs: WidgetInstance, rhs: WidgetInstance) -> Bool {
        lhs.typeID == rhs.typeID && lhs.config == rhs.config && lhs.v1Style == rhs.v1Style
            && lhs.v1PopupStyle == rhs.v1PopupStyle
            && lhs.v1Format == rhs.v1Format
            && lhs.v1Activate == rhs.v1Activate
            && lhs.v1Motion == rhs.v1Motion
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(typeID)
        hasher.combine(config)
        hasher.combine(v1Style)
        hasher.combine(v1PopupStyle)
        hasher.combine(v1Format)
        hasher.combine(v1Activate)
        hasher.combine(v1Motion)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        guard container.allKeys.count == 1, let key = container.allKeys.first else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription:
                        "Each widget must be a mapping with exactly one widget type key."
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
    public var style: WidgetStyleConfig
    public var barPadding: KamidanaInsets
    public var left: [WidgetInstance]
    public var center: [WidgetInstance]
    public var right: [WidgetInstance]

    public init(
        style: WidgetStyleConfig = WidgetStyleConfig.defaultNormal,
        barPadding: KamidanaInsets = KamidanaInsets(),
        left: [WidgetInstance] = [],
        center: [WidgetInstance] = [],
        right: [WidgetInstance] = []
    ) {
        self.style = style
        self.barPadding = barPadding
        self.left = left
        self.center = center
        self.right = right
    }

    private enum CodingKeys: String, CodingKey {
        case style
        case barPadding = "bar_padding"
        case left
        case center
        case right
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            style: try container.decodeIfPresent(WidgetStyleConfig.self, forKey: .style)
                ?? WidgetStyleConfig.defaultNormal,
            barPadding: try container.decodeIfPresent(KamidanaInsets.self, forKey: .barPadding)
                ?? KamidanaInsets(),
            left: try container.decodeIfPresent([WidgetInstance].self, forKey: .left) ?? [],
            center: try container.decodeIfPresent([WidgetInstance].self, forKey: .center) ?? [],
            right: try container.decodeIfPresent([WidgetInstance].self, forKey: .right) ?? []
        )
    }
}

// MARK: - Main Config Struct

public struct Config: Decodable {
    public let UserConfigPath: String = ""
    public let barTopPadding: Int64 = 0
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
                                action: "aboutThisMac", name: "About this Mac", icon: "󰌢",
                                iconColor: "#94e2d5")),
                        WidgetInstance(
                            typeID: "systemAction",
                            config: SystemActionWidgetConfig(
                                action: "sleep", name: "Sleep", icon: "󰒲", iconColor: "#94e2d5")),
                        WidgetInstance(
                            typeID: "systemAction",
                            config: SystemActionWidgetConfig(
                                action: "shutdown", name: "Shutdown", icon: "⏻",
                                iconColor: "#f38ba8")),
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
                                action: "lockScreen", name: "Screen Lock", icon: "󰌾",
                                iconColor: "#f5c2e7")),
                    ])),
            WidgetInstance(typeID: "audio", config: AudioWidgetConfig()),
        ],
        center: [
            WidgetInstance(
                typeID: "music",
                config: MusicWidgetConfig(placement: .center)
            ),
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
                                action: "aboutThisMac", name: "About this Mac", icon: "󰌢",
                                iconColor: "#94e2d5")),
                        WidgetInstance(
                            typeID: "systemAction",
                            config: SystemActionWidgetConfig(
                                action: "sleep", name: "Sleep", icon: "󰒲", iconColor: "#94e2d5")),
                        WidgetInstance(
                            typeID: "systemAction",
                            config: SystemActionWidgetConfig(
                                action: "shutdown", name: "Shutdown", icon: "⏻",
                                iconColor: "#f38ba8")),
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
                                action: "lockScreen", name: "Screen Lock", icon: "󰌾",
                                iconColor: "#f5c2e7")),
                    ])),
            WidgetInstance(typeID: "audio", config: AudioWidgetConfig()),
        ],
        center: [
            WidgetInstance(
                typeID: "music",
                config: MusicWidgetConfig(placement: .center)
            ),
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
                        name: "", icon: "󰇙", iconFolded: "", iconColor: "#cba6f7",
                        direction: "left",
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
            try container.decodeIfPresent(GlobalColorsConfig.self, forKey: .colors)
            ?? defaults.colors
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

private struct LegacyMonitorDisplayConfiguration: Decodable {
    let style: KamidanaStyle?
    let left: KamidanaConfigurationV1Section?
    let center: KamidanaConfigurationV1Center
    let right: KamidanaConfigurationV1Section?
}

private struct LegacyRegularMonitorConfiguration: Decodable {
    let global: KamidanaConfigurationV1Global?
    let externalMonitor: LegacyMonitorDisplayConfiguration?

    private enum CodingKeys: String, CodingKey {
        case global
        case externalMonitor = "external_monitor"
    }
}

private struct LegacyBuiltInMonitorConfiguration: Decodable {
    let global: KamidanaConfigurationV1Global?
    let builtInMonitor: LegacyMonitorDisplayConfiguration?

    private enum CodingKeys: String, CodingKey {
        case global
        case builtInMonitor = "built_in_monitor"
    }
}

private enum MonitorConfigurationRole {
    case regular
    case builtIn
}

public enum ConfigManagerError: LocalizedError {
    case configurationFileNotFound(URL)
    case combinedMonitorProfilesRequired
    case yamlMappingRequired
    case launchAtLoginRequiresBlockGlobal
    case launchAtLoginRequiresDirectScalar

    public var errorDescription: String? {
        switch self {
        case .configurationFileNotFound(let url):
            return "Configuration file not found at \(url.path)."
        case .combinedMonitorProfilesRequired:
            return
                "Launch at login can be updated only in a combined monitor profile configuration."
        case .yamlMappingRequired:
            return "Configuration must be a YAML mapping."
        case .launchAtLoginRequiresBlockGlobal:
            return "Launch at login requires a standard top-level 'global:' block mapping."
        case .launchAtLoginRequiresDirectScalar:
            return "Launch at login must be a direct plain scalar in the top-level 'global:' block."
        }
    }
}

private struct YAMLSourceLine {
    let contentRange: Range<String.Index>
    let endIndex: String.Index
}

public class ConfigManager {

    public static let shared = ConfigManager()
    public static let configDidChangeNotification = Notification.Name("KamidanaConfigDidChange")
    public var currentConfig = Config()
    /// Settings shared by the external and built-in monitor layouts.
    public private(set) var globalV1Config = KamidanaConfigurationV1Global()
    public private(set) var regularV1Config: KamidanaConfigurationV1?
    public private(set) var builtInV1Config: KamidanaConfigurationV1?
    public private(set) var monitorProfiles: KamidanaMonitorConfigurationV1?

    public static let MAIN_CONFIG_FILE_NAME = "config.yaml"
    public static let BUILT_IN_CONFIG_FILE_NAME = "built_in_monitor.yaml"
    public static let CONFIG_PARENT_DIR_NAME = ".config"
    public static let CONFIG_DIR_NAME = "kamidana"

    private var regularColors = GlobalColorsConfig()
    private var builtInColors = GlobalColorsConfig()
    private var isUsingBuiltInConfiguration = false

    public var currentV1Config: KamidanaConfigurationV1? {
        configurationForDisplay(isBuiltIn: isUsingBuiltInConfiguration)
    }

    public init(shouldLoadUserConfiguration: Bool = true) {
        if shouldLoadUserConfiguration {
            _ = loadConfig()
        }
    }

    public func loadConfig(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> Result<Bool, Error> {
        let configURL = resolveConfigFileURL(homeDirectory: homeDirectory)
        let legacyBuiltInURL = resolveBuiltInConfigFileURL(homeDirectory: homeDirectory)
        let fileManager = FileManager.default
        let hasConfiguration = fileManager.fileExists(atPath: configURL.path)
        let hasLegacyBuiltInConfiguration = fileManager.fileExists(atPath: legacyBuiltInURL.path)

        guard hasConfiguration || hasLegacyBuiltInConfiguration else {
            print(
                "Config file not found in \(resolveConfigDirectory(homeDirectory: homeDirectory).path), using defaults"
            )
            return .failure(NSError(domain: "", code: 0, userInfo: nil))
        }

        do {
            if hasConfiguration {
                let yaml = try String(contentsOf: configURL, encoding: .utf8)
                if Self.usesMonitorProfileSchema(yaml: yaml) {
                    try applyV1Configuration(yaml: yaml)
                    print("[LOG] Successfully loaded monitor profiles from \(configURL.path)")
                    return .success(true)
                } else if hasLegacyBuiltInConfiguration {
                    let legacyBuiltInYAML = try String(
                        contentsOf: legacyBuiltInURL, encoding: .utf8)
                    try applyV1Configurations(regularYAML: yaml, builtInYAML: legacyBuiltInYAML)
                    print("[LOG] Successfully loaded legacy separate monitor config files")
                    return .success(true)
                } else {
                    try applyV1Configurations(regularYAML: yaml, builtInYAML: yaml)
                    print("[LOG] Successfully loaded shared legacy config from \(configURL.path)")
                    return .success(true)
                }
            } else {
                let legacyYAML = try String(contentsOf: legacyBuiltInURL, encoding: .utf8)
                try applyV1Configurations(regularYAML: legacyYAML, builtInYAML: legacyYAML)
                print("[LOG] Successfully loaded legacy config from \(legacyBuiltInURL.path)")
                return .success(true)
            }
        } catch {
            print("Failed to decode v1 config: \(error)")
            return .failure(error)
        }
    }

    /// Updates the shared launch-at-login setting after validating the complete combined profile.
    public func updateLaunchAtLogin(
        isEnabled: Bool,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws {
        try updateLaunchAtLogin(
            isEnabled: isEnabled,
            configurationFileURL: resolveConfigFileURL(homeDirectory: homeDirectory)
        )
    }

    /// Updates the shared launch-at-login setting in an explicitly supplied configuration file.
    public func updateLaunchAtLogin(
        isEnabled: Bool,
        configurationFileURL: URL
    ) throws {
        guard FileManager.default.fileExists(atPath: configurationFileURL.path) else {
            throw ConfigManagerError.configurationFileNotFound(configurationFileURL)
        }

        let originalData = try Data(contentsOf: configurationFileURL)
        guard let yaml = String(data: originalData, encoding: .utf8) else {
            throw ConfigManagerError.yamlMappingRequired
        }

        // Decode and validate before altering the source file.
        _ = try KamidanaMonitorConfigurationV1Decoder.decode(yaml: yaml)
        guard Self.usesMonitorProfileSchema(yaml: yaml) else {
            throw ConfigManagerError.combinedMonitorProfilesRequired
        }

        let updatedData = try Self.updatedLaunchAtLoginData(
            yaml: yaml,
            originalData: originalData,
            isEnabled: isEnabled
        )
        try updatedData.write(to: configurationFileURL, options: .atomic)
    }

    private static func updatedLaunchAtLoginData(
        yaml: String,
        originalData: Data,
        isEnabled: Bool
    ) throws -> Data {
        guard let document = try Yams.load(yaml: yaml) as? [String: Any] else {
            throw ConfigManagerError.yamlMappingRequired
        }

        let lines = sourceLines(in: yaml)
        let globalHeaderIndexes = lines.indices.filter {
            globalHeaderKind(in: yaml[lines[$0].contentRange]) != nil
        }
        guard globalHeaderIndexes.count <= 1 else {
            throw ConfigManagerError.launchAtLoginRequiresBlockGlobal
        }

        let hasGlobal = document.keys.contains("global")
        guard let globalHeaderIndex = globalHeaderIndexes.first else {
            guard !hasGlobal, canInsertGlobalBlock(in: yaml, lines: lines) else {
                throw ConfigManagerError.launchAtLoginRequiresBlockGlobal
            }
            let insertionIndex =
                yaml.first == "\u{FEFF}"
                ? yaml.index(after: yaml.startIndex)
                : yaml.startIndex
            return try applying(
                replacement: "global:\n  launch_at_login: \(isEnabled)\n\n",
                to: insertionIndex..<insertionIndex,
                in: yaml,
                originalData: originalData
            )
        }

        guard hasGlobal,
            globalHeaderKind(in: yaml[lines[globalHeaderIndex].contentRange]) == .block
        else {
            throw ConfigManagerError.launchAtLoginRequiresBlockGlobal
        }

        let globalHeader = lines[globalHeaderIndex]
        let globalBlockEnd = endOfBlock(
            after: globalHeaderIndex,
            parentIndentation: 0,
            in: yaml,
            lines: lines
        )
        let globalMapping = document["global"] as? [String: Any]
        let hasLaunchAtLogin = globalMapping?.keys.contains("launch_at_login") ?? false
        var directChildIndentation: Int?
        var launchAtLoginValueRanges: [Range<String.Index>] = []
        var lastGlobalContentIndex: Int?

        for lineIndex in (globalHeaderIndex + 1)..<globalBlockEnd {
            let line = yaml[lines[lineIndex].contentRange]
            guard !isBlankOrComment(line) else { continue }

            let indentation = leadingSpaceCount(in: line)
            lastGlobalContentIndex = lineIndex
            if directChildIndentation == nil {
                directChildIndentation = indentation
            }
            guard indentation == directChildIndentation else { continue }

            if let range = try launchAtLoginValueRange(
                in: line,
                indentation: indentation
            ) {
                launchAtLoginValueRanges.append(range)
            }
        }

        guard launchAtLoginValueRanges.count <= 1 else {
            throw ConfigManagerError.launchAtLoginRequiresDirectScalar
        }
        if let valueRange = launchAtLoginValueRanges.first {
            return try applying(
                replacement: String(isEnabled),
                to: valueRange,
                in: yaml,
                originalData: originalData
            )
        }
        guard !hasLaunchAtLogin else {
            throw ConfigManagerError.launchAtLoginRequiresDirectScalar
        }

        let indentation = String(repeating: " ", count: directChildIndentation ?? 2)
        let insertionLine = lastGlobalContentIndex.map { lines[$0] } ?? globalHeader
        let insertionIndex = insertionLine.endIndex
        let lineEnding = String(
            yaml[insertionLine.contentRange.upperBound..<insertionLine.endIndex])
        let replacement: String
        if lineEnding.isEmpty {
            replacement = "\n\(indentation)launch_at_login: \(isEnabled)"
        } else {
            replacement = "\(indentation)launch_at_login: \(isEnabled)\(lineEnding)"
        }
        return try applying(
            replacement: replacement,
            to: insertionIndex..<insertionIndex,
            in: yaml,
            originalData: originalData
        )
    }

    private static func sourceLines(in yaml: String) -> [YAMLSourceLine] {
        var lines: [YAMLSourceLine] = []
        var lineStart = yaml.startIndex

        while lineStart < yaml.endIndex {
            var lineEnd = lineStart
            while lineEnd < yaml.endIndex, yaml[lineEnd] != "\n", yaml[lineEnd] != "\r" {
                lineEnd = yaml.index(after: lineEnd)
            }

            var nextLineStart = lineEnd
            if nextLineStart < yaml.endIndex {
                let firstLineEndingCharacter = yaml[nextLineStart]
                nextLineStart = yaml.index(after: nextLineStart)
                if firstLineEndingCharacter == "\r",
                    nextLineStart < yaml.endIndex,
                    yaml[nextLineStart] == "\n"
                {
                    nextLineStart = yaml.index(after: nextLineStart)
                }
            }

            lines.append(YAMLSourceLine(contentRange: lineStart..<lineEnd, endIndex: nextLineStart))
            lineStart = nextLineStart
        }

        return lines
    }

    private static func globalHeaderKind(in line: Substring) -> GlobalHeaderKind? {
        let content = line.first == "\u{FEFF}" ? line.dropFirst() : line[...]
        guard content.starts(with: "global:") else { return nil }

        let valueStart = content.index(content.startIndex, offsetBy: "global:".count)
        let value = content[valueStart...]
        guard value.isEmpty || value.first?.isWhitespace == true else { return .unsupported }

        let trimmedValue = value.trimmingCharacters(in: .whitespaces)
        guard !trimmedValue.isEmpty, trimmedValue.first != "#" else { return .block }
        guard trimmedValue.first == "&" else { return .unsupported }

        let anchor = trimmedValue.dropFirst().prefix { !$0.isWhitespace }
        let remaining = trimmedValue.dropFirst().dropFirst(anchor.count)
            .trimmingCharacters(in: .whitespaces)
        return !anchor.isEmpty && (remaining.isEmpty || remaining.first == "#")
            ? .block : .unsupported
    }

    private enum GlobalHeaderKind {
        case block
        case unsupported
    }

    private static func canInsertGlobalBlock(in yaml: String, lines: [YAMLSourceLine]) -> Bool {
        for line in lines {
            let lineContent = yaml[line.contentRange]
            let content = lineContent.first == "\u{FEFF}" ? lineContent.dropFirst() : lineContent
            guard !isBlankOrComment(content) else { continue }
            guard leadingSpaceCount(in: content) == 0,
                !content.starts(with: "---"),
                !content.starts(with: "%")
            else { return false }

            guard let firstCharacter = content.first,
                !"{[*&!".contains(firstCharacter)
            else { return false }
            return true
        }
        return false
    }

    private static func endOfBlock(
        after headerIndex: Int,
        parentIndentation: Int,
        in yaml: String,
        lines: [YAMLSourceLine]
    ) -> Int {
        for lineIndex in (headerIndex + 1)..<lines.count {
            let line = yaml[lines[lineIndex].contentRange]
            if !isBlankOrComment(line), leadingSpaceCount(in: line) <= parentIndentation {
                return lineIndex
            }
        }
        return lines.count
    }

    private static func launchAtLoginValueRange(
        in line: Substring,
        indentation: Int
    ) throws -> Range<String.Index>? {
        guard leadingSpaceCount(in: line) == indentation else { return nil }
        let keyStart = line.index(line.startIndex, offsetBy: indentation)
        let key = "launch_at_login:"
        guard line[keyStart...].starts(with: key) else { return nil }

        let valueStart = line.index(keyStart, offsetBy: key.count)
        guard valueStart == line.endIndex || line[valueStart].isWhitespace else { return nil }
        let commentStart = inlineCommentStart(in: line[valueStart...]) ?? line.endIndex
        var scalarStart = valueStart
        while scalarStart < commentStart, line[scalarStart].isWhitespace {
            scalarStart = line.index(after: scalarStart)
        }
        var scalarEnd = commentStart
        while scalarEnd > scalarStart, line[line.index(before: scalarEnd)].isWhitespace {
            scalarEnd = line.index(before: scalarEnd)
        }

        let scalar = line[scalarStart..<scalarEnd]
        guard !scalar.isEmpty,
            !scalar.contains(where: \Character.isWhitespace),
            !"*&!\"'[{|>".contains(scalar.first!)
        else {
            throw ConfigManagerError.launchAtLoginRequiresDirectScalar
        }
        return scalarStart..<scalarEnd
    }

    private static func inlineCommentStart(in value: Substring) -> String.Index? {
        var index = value.startIndex
        while index < value.endIndex {
            if value[index] == "#",
                index > value.startIndex,
                value[value.index(before: index)].isWhitespace
            {
                return index
            }
            index = value.index(after: index)
        }
        return nil
    }

    private static func isBlankOrComment(_ line: Substring) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed.first == "#"
    }

    private static func leadingSpaceCount(in line: Substring) -> Int {
        line.prefix { $0 == " " }.count
    }

    private static func applying(
        replacement: String,
        to range: Range<String.Index>,
        in yaml: String,
        originalData: Data
    ) throws -> Data {
        let stringByteCount = yaml.utf8.count
        let leadingByteCount = originalData.count - stringByteCount
        guard leadingByteCount >= 0,
            let start = range.lowerBound.samePosition(in: yaml.utf8),
            let end = range.upperBound.samePosition(in: yaml.utf8)
        else {
            throw ConfigManagerError.launchAtLoginRequiresBlockGlobal
        }

        let startOffset =
            leadingByteCount + yaml.utf8.distance(from: yaml.utf8.startIndex, to: start)
        let endOffset = leadingByteCount + yaml.utf8.distance(from: yaml.utf8.startIndex, to: end)
        guard startOffset <= endOffset, endOffset <= originalData.count else {
            throw ConfigManagerError.launchAtLoginRequiresBlockGlobal
        }

        var updatedData = Data()
        updatedData.append(contentsOf: originalData.prefix(startOffset))
        updatedData.append(contentsOf: replacement.utf8)
        updatedData.append(contentsOf: originalData.suffix(from: endOffset))
        return updatedData
    }

    public func applyV1Configuration(yaml: String) throws {
        if Self.usesMonitorProfileSchema(yaml: yaml) {
            let profiles = try KamidanaMonitorConfigurationV1Decoder.decode(yaml: yaml)
            self.monitorProfiles = profiles

            let fallback = KamidanaConfigurationV1(
                global: profiles.global, left: .init(widgets: []),
                center: .init(centerDefault: "", widgets: []), right: .init(widgets: []))

            applyDecodedConfigurations(
                regularConfiguration: profiles.displays["external"] ?? profiles.displays[
                    "default_layout"] ?? fallback,
                builtInConfiguration: profiles.displays["built_in"] ?? profiles.displays[
                    "default_layout"] ?? fallback
            )
        } else {
            try applyV1Configurations(regularYAML: yaml, builtInYAML: yaml)
        }
    }

    public func applyV1Configurations(regularYAML: String, builtInYAML: String) throws {
        let regularConfiguration = try decodeConfiguration(
            yaml: regularYAML,
            role: .regular
        )
        let builtInConfiguration = try decodeConfiguration(
            yaml: builtInYAML,
            role: .builtIn
        )
        monitorProfiles = nil
        applyDecodedConfigurations(
            regularConfiguration: regularConfiguration,
            builtInConfiguration: builtInConfiguration
        )
    }

    private func applyDecodedConfigurations(
        regularConfiguration: KamidanaConfigurationV1,
        builtInConfiguration: KamidanaConfigurationV1
    ) {
        let regularRuntime = KamidanaConfigurationV1Adapter.makeLegacyConfig(
            from: regularConfiguration
        )
        let builtInRuntime = KamidanaConfigurationV1Adapter.makeLegacyConfig(
            from: builtInConfiguration
        )

        var combinedRuntime = regularRuntime
        combinedRuntime.builtInDisplay = builtInRuntime.builtInDisplay

        regularV1Config = regularConfiguration
        builtInV1Config = builtInConfiguration
        globalV1Config = regularConfiguration.global
        regularColors = regularRuntime.colors
        builtInColors = builtInRuntime.colors
        currentConfig = combinedRuntime
        activateConfiguration(isBuiltIn: isUsingBuiltInConfiguration)
    }

    private static func usesMonitorProfileSchema(yaml: String) -> Bool {
        guard let value = try? Yams.load(yaml: yaml),
            let mapping = value as? [String: Any]
        else { return false }
        return mapping.keys.contains("external") || mapping.keys.contains("built_in")
            || mapping.keys.contains("default_layout")
    }

    private func decodeConfiguration(
        yaml: String,
        role: MonitorConfigurationRole
    ) throws -> KamidanaConfigurationV1 {
        do {
            return try KamidanaConfigurationV1Decoder.decode(yaml: yaml)
        } catch {
            let currentSchemaError = error
            do {
                let global: KamidanaConfigurationV1Global?
                let display: LegacyMonitorDisplayConfiguration?
                switch role {
                case .regular:
                    let legacy = try YAMLDecoder().decode(
                        LegacyRegularMonitorConfiguration.self,
                        from: yaml
                    )
                    global = legacy.global
                    display = legacy.externalMonitor
                case .builtIn:
                    let legacy = try YAMLDecoder().decode(
                        LegacyBuiltInMonitorConfiguration.self,
                        from: yaml
                    )
                    global = legacy.global
                    display = legacy.builtInMonitor
                }

                guard let display else { throw currentSchemaError }
                let baseGlobal = global ?? KamidanaConfigurationV1Global()
                let configuration = KamidanaConfigurationV1(
                    global: KamidanaConfigurationV1Global(
                        backgroundMode: baseGlobal.backgroundMode,
                        hideInFullscreen: baseGlobal.hideInFullscreen,
                        launchAtLogin: baseGlobal.launchAtLogin,
                        displayTargets: baseGlobal.displayTargets,
                        style: display.style.map {
                            KamidanaConfigurationV1Adapter.mergedStyle(baseGlobal.style, $0)
                        } ?? baseGlobal.style,
                        popupStyle: baseGlobal.popupStyle,
                        barPadding: baseGlobal.barPadding
                    ),
                    left: display.left ?? KamidanaConfigurationV1Section(),
                    center: display.center,
                    right: display.right ?? KamidanaConfigurationV1Section()
                )
                try configuration.validate()
                return configuration
            } catch {
                throw currentSchemaError
            }
        }
    }
    public func configuration(for screen: NSScreen) -> KamidanaConfigurationV1? {
        if let profiles = monitorProfiles {
            let displays = profiles.displays

            // 1. Try ID
            if let displayID = DisplayDetector.displayID(for: screen) {
                if let config = displays[String(displayID)] { return config }
            }

            // 2. Try Name
            if let config = displays[screen.localizedName] { return config }

            // 3. Try Type
            let isBuiltIn = DisplayDetector.isBuiltIn(screen: screen)
            if isBuiltIn, let config = displays["built_in"] { return config }
            if !isBuiltIn, let config = displays["external"] { return config }

            // 4. Fallback to default layout
            if let config = displays["default_layout"] { return config }

            return displays.values.first
        }

        // Legacy fallback
        let isBuiltIn = DisplayDetector.isBuiltIn(screen: screen)
        return configurationForDisplay(isBuiltIn: isBuiltIn)
    }

    public func layout(for screen: NSScreen) -> DisplayLayoutConfig {
        let v1 =
            configuration(for: screen)
            ?? KamidanaConfigurationV1(
                global: KamidanaConfigurationV1Global(),
                left: KamidanaConfigurationV1Section(widgets: []),
                center: KamidanaConfigurationV1Center(centerDefault: "", widgets: []),
                right: KamidanaConfigurationV1Section(widgets: [])
            )
        return KamidanaConfigurationV1Adapter.makeLegacyConfig(from: v1).externalDisplay
    }

    public func configurationForDisplay(isBuiltIn: Bool) -> KamidanaConfigurationV1? {
        if isBuiltIn {
            return builtInV1Config ?? regularV1Config
        }
        return regularV1Config ?? builtInV1Config
    }

    public func activateConfiguration(isBuiltIn: Bool) {
        isUsingBuiltInConfiguration = isBuiltIn
        currentConfig.colors = isBuiltIn ? builtInColors : regularColors
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

    /// Resolves the legacy built-in display configuration file URL for migration support.
    public func resolveBuiltInConfigFileURL(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        return resolveConfigDirectory(homeDirectory: homeDirectory)
            .appendingPathComponent(Self.BUILT_IN_CONFIG_FILE_NAME)
    }

    /// Returns the path string of the user's config directory (~/.config/kamidana)
    public func fetchUserConfigPath() -> String {
        return resolveConfigDirectory().path
    }

    // MARK: - Auto config reload
    private var fileWatcher: DispatchSourceFileSystemObject?
    private var fileWatcherQueue: DispatchQueue = DispatchQueue(label: "com.kamidana.configWatcher")

    public func startWatchingConfig(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        print("[LOG] Start config watcher")
        let configDirectoryURL = resolveConfigDirectory(homeDirectory: homeDirectory)
        let fileDescriptor = open(configDirectoryURL.path, O_EVTONLY)
        guard fileDescriptor != -1 else { return }

        fileWatcher?.cancel()
        fileWatcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete, .attrib],
            queue: fileWatcherQueue
        )

        fileWatcher?.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                guard case .success = self.loadConfig(homeDirectory: homeDirectory) else {
                    return
                }
                NotificationCenter.default.post(
                    name: Self.configDidChangeNotification,
                    object: nil
                )
            }
        }
        fileWatcher?.setCancelHandler { close(fileDescriptor) }

        fileWatcher?.resume()
    }
}
