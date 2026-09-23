import Foundation
import Yams

private struct KamidanaConfigurationCodingKey: CodingKey {
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

private func rejectUnknownKeys<Key: CodingKey & CaseIterable>(
    in decoder: Decoder,
    knownBy _: Key.Type
) throws {
    let container = try decoder.container(keyedBy: KamidanaConfigurationCodingKey.self)
    let knownKeys = Set(Key.allCases.map(\.stringValue))
    guard let unknownKey = container.allKeys.first(where: { !knownKeys.contains($0.stringValue) })
    else { return }

    print("[Config Warning] Unknown configuration key '\(unknownKey.stringValue)'.")
}

private func displayTargetError(in message: String) -> KamidanaConfigurationV1Error? {
    guard let marker = message.range(of: "Invalid display target at ") else { return nil }
    let details = message[marker.upperBound...]
    let parts = details.split(separator: ":", maxSplits: 1)
    guard parts.count == 2 else { return nil }
    return .invalidDisplayTarget(
        path: String(parts[0]),
        reason: String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
    )
}

/// Errors reported while decoding or validating the independent v1 configuration schema.
public enum KamidanaConfigurationV1Error: Error, CustomStringConvertible, Equatable {
    case yamlDecoding(String)
    case unsupportedWidgetType(String)
    case duplicateID(String)
    case invalidCenterDefault(String)
    case centerDefaultRequiresCompactFormat(String)
    case btopMustBeInCenter(String)
    case tooltipNotAllowed(String)
    case tooltipFormatRequired(String)
    case emptyCustomCommand(String)
    case invalidStyle(path: String, reason: String)
    case invalidWidget(path: String, reason: String)
    case invalidDisplayTarget(path: String, reason: String)

    public var description: String {
        switch self {
        case .yamlDecoding(let message):
            return "YAML decoding failed: \(message)"
        case .unsupportedWidgetType(let type):
            return "Unsupported widget type '\(type)'."
        case .duplicateID(let id):
            return "Widget ID '\(id)' is not globally unique."
        case .invalidCenterDefault(let id):
            return "center_default must reference a widget ID in center; received '\(id)'."
        case .centerDefaultRequiresCompactFormat(let id):
            return
                "The center_default widget '\(id)' must define compact_format, format, or music normal.format."
        case .btopMustBeInCenter(let id):
            return "The btop widget '\(id)' is valid only in center."
        case .tooltipNotAllowed(let path):
            return
                "tooltip and tooltip_format are allowed only for cpu, gpu, memory, and network (at \(path))."
        case .tooltipFormatRequired(let path):
            return "tooltip_format must be non-empty when tooltip is true (at \(path))."
        case .emptyCustomCommand(let path):
            return "custom.command must be non-empty (at \(path))."
        case .invalidStyle(let path, let reason):
            return "Invalid style at \(path): \(reason)"
        case .invalidWidget(let path, let reason):
            return "Invalid widget at \(path): \(reason)"
        case .invalidDisplayTarget(let path, let reason):
            return "Invalid display target at \(path): \(reason)"
        }
    }
}

public enum KamidanaBackgroundMode: String, Codable, Equatable {
    case singleBar = "single_bar"
    case perSection = "per_section"
    case perWidget = "per_widget"
    case none
}

public enum KamidanaMaterial: String, Codable, Equatable {
    case none
    case ultraThin = "ultra_thin"
    case thin
    case regular
    case thick
    case chrome
}

public enum KamidanaAnimationPreset: String, Codable, Equatable {
    case none
    case linear
    case easeInOut = "ease_in_out"
    case spring
}

public enum KamidanaActivation: String, Codable, Equatable {
    case hover
    case click
}

public enum KamidanaMotion: String, Codable, Equatable {
    case `static`
    case dynamic
}

public enum KamidanaDisplayTargetKind: String, Decodable, Equatable {
    case primary
    case secondary
    case builtIn = "built_in"
    case external
    case all
    case name
    case id
}

/// A validated selector for the screens that should host the status bar.
public struct KamidanaDisplayTarget: Decodable, Equatable {
    public var kind: KamidanaDisplayTargetKind
    public var name: String?
    public var id: UInt32?

    public init(
        kind: KamidanaDisplayTargetKind,
        name: String? = nil,
        id: UInt32? = nil
    ) {
        self.kind = kind
        self.name = name
        self.id = id
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind, name, id
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(in: decoder, knownBy: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            kind: try container.decode(KamidanaDisplayTargetKind.self, forKey: .kind),
            name: try container.decodeIfPresent(String.self, forKey: .name),
            id: try container.decodeIfPresent(UInt32.self, forKey: .id)
        )
        try validate(path: "display target")
    }

    fileprivate func validate(path: String) throws {
        switch kind {
        case .name:
            guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw KamidanaConfigurationV1Error.invalidDisplayTarget(
                    path: path, reason: "name must be non-empty for kind 'name'"
                )
            }
            guard id == nil else {
                throw KamidanaConfigurationV1Error.invalidDisplayTarget(
                    path: path, reason: "id is allowed only for kind 'id'"
                )
            }
        case .id:
            guard let id, id != 0 else {
                throw KamidanaConfigurationV1Error.invalidDisplayTarget(
                    path: path, reason: "id must be a positive display ID for kind 'id'"
                )
            }
            guard name == nil else {
                throw KamidanaConfigurationV1Error.invalidDisplayTarget(
                    path: path, reason: "name is allowed only for kind 'name'"
                )
            }
        case .primary, .secondary, .builtIn, .external, .all:
            guard name == nil, id == nil else {
                throw KamidanaConfigurationV1Error.invalidDisplayTarget(
                    path: path, reason: "name and id are not allowed for kind '\(kind.rawValue)'"
                )
            }
        }
    }
}

public enum KamidanaMusicExtendDirection: String, Codable, Equatable {
    case left
    case right
}

public enum KamidanaWidgetFolderDirection: String, Codable, Equatable {
    case below
    case left
    case right
}

public struct KamidanaInsets: Codable, Hashable {
    public var top: Double
    public var bottom: Double
    public var leading: Double
    public var trailing: Double

    public init(top: Double = 0, bottom: Double = 0, leading: Double = 0, trailing: Double = 0) {
        self.top = top
        self.bottom = bottom
        self.leading = leading
        self.trailing = trailing
    }

    public init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer().decode(Double.self) {
            self.init(top: single, bottom: single, leading: single, trailing: single)
            return
        }

        if let values = try? decoder.singleValueContainer().decode([Double].self) {
            guard values.count == 4 else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "Padding requires four values")
                )
            }
            self.init(top: values[0], bottom: values[2], leading: values[3], trailing: values[1])
            return
        }

        if let text = try? decoder.singleValueContainer().decode(String.self) {
            let values = text.split(separator: ",").compactMap {
                Double($0.trimmingCharacters(in: .whitespaces))
            }
            guard values.count == 4 else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "Padding requires four comma-separated values")
                )
            }
            self.init(top: values[0], bottom: values[2], leading: values[3], trailing: values[1])
            return
        }

        try rejectUnknownKeys(in: decoder, knownBy: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            top: try container.decodeIfPresent(Double.self, forKey: .top) ?? 0,
            bottom: try container.decodeIfPresent(Double.self, forKey: .bottom) ?? 0,
            leading: try container.decodeIfPresent(Double.self, forKey: .leading) ?? 0,
            trailing: try container.decodeIfPresent(Double.self, forKey: .trailing) ?? 0
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case top, bottom, leading, trailing
    }
}

public struct KamidanaBorder: Codable, Hashable {
    public var width: Double
    public var color: String?

    public init(width: Double = 0, color: String? = nil) {
        self.width = width
        self.color = color
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case width, color
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(in: decoder, knownBy: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            width: try container.decodeIfPresent(Double.self, forKey: .width) ?? 0,
            color: try container.decodeIfPresent(String.self, forKey: .color)
        )
    }
}

public struct KamidanaShadow: Codable, Hashable {
    public var color: String?
    public var radius: Double
    public var x: Double
    public var y: Double
    public var opacity: Double

    public init(
        color: String? = nil, radius: Double = 0, x: Double = 0, y: Double = 0, opacity: Double = 1
    ) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
        self.opacity = opacity
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case color, radius, x, y, opacity
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(in: decoder, knownBy: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            color: try container.decodeIfPresent(String.self, forKey: .color),
            radius: try container.decodeIfPresent(Double.self, forKey: .radius) ?? 0,
            x: try container.decodeIfPresent(Double.self, forKey: .x) ?? 0,
            y: try container.decodeIfPresent(Double.self, forKey: .y) ?? 0,
            opacity: try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1
        )
    }
}

public struct KamidanaAnimation: Codable, Hashable {
    public var preset: KamidanaAnimationPreset
    public var durationSeconds: Double?
    public var damping: Double?
    public var response: Double?
    public var blendDuration: Double?

    public init(
        preset: KamidanaAnimationPreset,
        durationSeconds: Double? = nil,
        damping: Double? = nil,
        response: Double? = nil,
        blendDuration: Double? = nil
    ) {
        self.preset = preset
        self.durationSeconds = durationSeconds
        self.damping = damping
        self.response = response
        self.blendDuration = blendDuration
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case preset
        case durationSeconds = "duration_seconds"
        case damping
        case response
        case blendDuration = "blend_duration"
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(in: decoder, knownBy: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            preset: try container.decode(KamidanaAnimationPreset.self, forKey: .preset),
            durationSeconds: try container.decodeIfPresent(Double.self, forKey: .durationSeconds),
            damping: try container.decodeIfPresent(Double.self, forKey: .damping),
            response: try container.decodeIfPresent(Double.self, forKey: .response),
            blendDuration: try container.decodeIfPresent(Double.self, forKey: .blendDuration)
        )
    }
}

/// A deliberately small, typed appearance model. It is not a CSS or cascade engine.
public struct KamidanaStyle: Codable, Hashable {
    public var background: String?
    public var color: String?
    public var iconColor: String?
    public var chargingColor: String?
    public var dischargingColor: String?
    public var warningColor: String?
    public var dangerColor: String?
    public var outlineColor: String?
    public var gradientColor1: String?
    public var gradientColor2: String?
    public var gradientColor3: String?
    public var gradientColor4: String?
    public var gradientColor5: String?
    public var opacity: Double?
    public var padding: KamidanaInsets?
    public var spacing: Double?
    public var cornerRadius: Double?
    public var border: KamidanaBorder?
    public var shadow: KamidanaShadow?
    public var material: KamidanaMaterial?
    public var animation: KamidanaAnimation?
    public var states: [String: KamidanaStyle]

    public init(
        background: String? = nil,
        color: String? = nil,
        iconColor: String? = nil,
        chargingColor: String? = nil,
        dischargingColor: String? = nil,
        warningColor: String? = nil,
        dangerColor: String? = nil,
        outlineColor: String? = nil,
        gradientColor1: String? = nil,
        gradientColor2: String? = nil,
        gradientColor3: String? = nil,
        gradientColor4: String? = nil,
        gradientColor5: String? = nil,
        opacity: Double? = nil,
        padding: KamidanaInsets? = nil,
        spacing: Double? = nil,
        cornerRadius: Double? = nil,
        border: KamidanaBorder? = nil,
        shadow: KamidanaShadow? = nil,
        material: KamidanaMaterial? = nil,
        animation: KamidanaAnimation? = nil,
        states: [String: KamidanaStyle] = [:]
    ) {
        self.background = background
        self.color = color
        self.iconColor = iconColor
        self.chargingColor = chargingColor
        self.dischargingColor = dischargingColor
        self.warningColor = warningColor
        self.dangerColor = dangerColor
        self.outlineColor = outlineColor
        self.gradientColor1 = gradientColor1
        self.gradientColor2 = gradientColor2
        self.gradientColor3 = gradientColor3
        self.gradientColor4 = gradientColor4
        self.gradientColor5 = gradientColor5
        self.opacity = opacity
        self.padding = padding
        self.spacing = spacing
        self.cornerRadius = cornerRadius
        self.border = border
        self.shadow = shadow
        self.material = material
        self.animation = animation
        self.states = states
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case background, color
        case iconColor = "icon_color"
        case chargingColor = "charging_color"
        case dischargingColor = "discharging_color"
        case warningColor = "warning_color"
        case dangerColor = "danger_color"
        case outlineColor = "outline_color"
        case gradientColor1 = "gradient_color_1"
        case gradientColor2 = "gradient_color_2"
        case gradientColor3 = "gradient_color_3"
        case gradientColor4 = "gradient_color_4"
        case gradientColor5 = "gradient_color_5"
        case opacity
        case padding, spacing
        case cornerRadius = "corner_radius"
        case border, shadow, material, animation, states
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(in: decoder, knownBy: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            background: try container.decodeIfPresent(String.self, forKey: .background),
            color: try container.decodeIfPresent(String.self, forKey: .color),
            iconColor: try container.decodeIfPresent(String.self, forKey: .iconColor),
            chargingColor: try container.decodeIfPresent(String.self, forKey: .chargingColor),
            dischargingColor: try container.decodeIfPresent(String.self, forKey: .dischargingColor),
            warningColor: try container.decodeIfPresent(String.self, forKey: .warningColor),
            dangerColor: try container.decodeIfPresent(String.self, forKey: .dangerColor),
            outlineColor: try container.decodeIfPresent(String.self, forKey: .outlineColor),
            gradientColor1: try container.decodeIfPresent(String.self, forKey: .gradientColor1),
            gradientColor2: try container.decodeIfPresent(String.self, forKey: .gradientColor2),
            gradientColor3: try container.decodeIfPresent(String.self, forKey: .gradientColor3),
            gradientColor4: try container.decodeIfPresent(String.self, forKey: .gradientColor4),
            gradientColor5: try container.decodeIfPresent(String.self, forKey: .gradientColor5),
            opacity: try container.decodeIfPresent(Double.self, forKey: .opacity),
            padding: try container.decodeIfPresent(KamidanaInsets.self, forKey: .padding),
            spacing: try container.decodeIfPresent(Double.self, forKey: .spacing),
            cornerRadius: try container.decodeIfPresent(Double.self, forKey: .cornerRadius),
            border: try container.decodeIfPresent(KamidanaBorder.self, forKey: .border),
            shadow: try container.decodeIfPresent(KamidanaShadow.self, forKey: .shadow),
            material: try container.decodeIfPresent(KamidanaMaterial.self, forKey: .material),
            animation: try container.decodeIfPresent(KamidanaAnimation.self, forKey: .animation),
            states: try container.decodeIfPresent([String: KamidanaStyle].self, forKey: .states)
                ?? [:]
        )
    }
}

public enum KamidanaAudioVisualizerCaptureScope: String, Codable, Equatable, Hashable {
    case system
    case microphone
}

public enum KamidanaAudioVisualizerChannelMode: String, Codable, Equatable, Hashable {
    case stereo
    case mono
}

public enum KamidanaSoundVisualizerPosition: String, Codable, Equatable, Hashable {
    case top
    case bottom
    case left
    case right
}

public struct KamidanaSoundVisualizerConfig: Decodable, Equatable {
    public var format: String
    public var position: KamidanaSoundVisualizerPosition
    public var height: Int
    public var barWidth: Double
    public var padding: KamidanaInsets
    public var gradientSeparation: Int
    public var captureScope: KamidanaAudioVisualizerCaptureScope
    public var channelMode: KamidanaAudioVisualizerChannelMode
    public var smoothness: Double
    public var separationLength: Int
    public var style: KamidanaStyle

    public init(
        format: String = "{display}",
        position: KamidanaSoundVisualizerPosition = .bottom,
        height: Int = 1,
        barWidth: Double = 10,
        padding: KamidanaInsets = KamidanaInsets(),
        gradientSeparation: Int = 1,
        captureScope: KamidanaAudioVisualizerCaptureScope = .system,
        channelMode: KamidanaAudioVisualizerChannelMode = .stereo,
        smoothness: Double = 0.5,
        separationLength: Int = 5,
        style: KamidanaStyle = KamidanaStyle()
    ) {
        self.format = format
        self.position = position
        self.height = height
        self.barWidth = barWidth
        self.padding = padding
        self.gradientSeparation = gradientSeparation
        self.captureScope = captureScope
        self.channelMode = channelMode
        self.smoothness = smoothness
        self.separationLength = separationLength
        self.style = style
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case format, position, height
        case barWidth = "bar_width"
        case padding
        case gradientSeparation = "gradient_separation"
        case captureScope = "capture_scope"
        case channelMode = "channel_mode"
        case smoothness
        case separationLength = "separation_length"
        case style
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(in: decoder, knownBy: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            format: try container.decodeIfPresent(String.self, forKey: .format) ?? "{display}",
            position: try container.decodeIfPresent(
                KamidanaSoundVisualizerPosition.self, forKey: .position) ?? .bottom,
            height: try container.decodeIfPresent(Int.self, forKey: .height) ?? 1,
            barWidth: try container.decodeIfPresent(Double.self, forKey: .barWidth) ?? 10,
            padding: try container.decodeIfPresent(KamidanaInsets.self, forKey: .padding)
                ?? KamidanaInsets(),
            gradientSeparation: try container.decodeIfPresent(Int.self, forKey: .gradientSeparation)
                ?? 1,
            captureScope: try container.decodeIfPresent(
                KamidanaAudioVisualizerCaptureScope.self, forKey: .captureScope) ?? .system,
            channelMode: try container.decodeIfPresent(
                KamidanaAudioVisualizerChannelMode.self, forKey: .channelMode) ?? .stereo,
            smoothness: try container.decodeIfPresent(Double.self, forKey: .smoothness) ?? 0.5,
            separationLength: try container.decodeIfPresent(Int.self, forKey: .separationLength)
                ?? 5,
            style: try container.decodeIfPresent(KamidanaStyle.self, forKey: .style)
                ?? KamidanaStyle()
        )
    }
}

public enum KamidanaWidgetKind: String, Codable, Equatable, CaseIterable {
    case music
    case volume
    case audioVisualizer = "audio-visualizer"
    case cpu
    case gpu
    case memory
    case network
    case disk
    case battery
    case clock
    case bluetooth
    case weather
    case custom
    case widgetFolder = "widget-folder"
    case systemAction = "system-action"
    case btop
}

public enum KamidanaSystemAction: String, Codable, Equatable {
    case sleep
    case reboot
    case shutdown
    case logout
    case lockScreen = "lock-screen"
    case aboutThisMac = "about-this-mac"
}

public struct KamidanaSystemActionChild: Decodable, Equatable {
    public let id: String
    public let action: KamidanaSystemAction
    public let format: String
    public let icon: String
    public let style: KamidanaStyle

    public init(
        id: String,
        action: KamidanaSystemAction,
        format: String,
        icon: String,
        style: KamidanaStyle = KamidanaStyle()
    ) {
        self.id = id
        self.action = action
        self.format = format
        self.icon = icon
        self.style = style
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case action = "type"
        case format, icon, style
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(in: decoder, knownBy: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            action: try container.decode(KamidanaSystemAction.self, forKey: .action),
            format: try container.decode(String.self, forKey: .format),
            icon: try container.decode(String.self, forKey: .icon),
            style: try container.decodeIfPresent(KamidanaStyle.self, forKey: .style)
                ?? KamidanaStyle()
        )
    }
}

public struct KamidanaMusicNormalState: Decodable, Equatable {
    public var format: String?
    public var formatOnAction: String?
    public var sliderChange: String?
    public var sliderPause: String?
    public var sliderBar: String?
    public var extend: KamidanaMusicExtendDirection?
    public var artworkSpin: Double?

    public init(
        format: String? = nil,
        formatOnAction: String? = nil,
        sliderChange: String? = nil,
        sliderPause: String? = nil,
        sliderBar: String? = nil,
        extend: KamidanaMusicExtendDirection? = nil,
        artworkSpin: Double? = nil
    ) {
        self.format = format
        self.formatOnAction = formatOnAction
        self.sliderChange = sliderChange
        self.sliderPause = sliderPause
        self.sliderBar = sliderBar
        self.extend = extend
        self.artworkSpin = artworkSpin
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case format
        case formatOnAction = "format_on_action"
        case sliderChange = "slider_change"
        case sliderPause = "slider_pause"
        case sliderBar = "slider_bar"
        case extend
        case artworkSpin = "artwork_spin"
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(in: decoder, knownBy: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            format: try container.decodeIfPresent(String.self, forKey: .format),
            formatOnAction: try container.decodeIfPresent(String.self, forKey: .formatOnAction),
            sliderChange: try container.decodeIfPresent(String.self, forKey: .sliderChange),
            sliderPause: try container.decodeIfPresent(String.self, forKey: .sliderPause),
            sliderBar: try container.decodeIfPresent(String.self, forKey: .sliderBar),
            extend: try container.decodeIfPresent(
                KamidanaMusicExtendDirection.self, forKey: .extend),
            artworkSpin: try container.decodeIfPresent(Double.self, forKey: .artworkSpin)
        )
    }
}

public struct KamidanaMusicActionState: Decodable, Equatable {
    public var format: String?
    public var artworkSpin: Double?

    public init(format: String? = nil, artworkSpin: Double? = nil) {
        self.format = format
        self.artworkSpin = artworkSpin
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case format
        case artworkSpin = "artwork_spin"
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(in: decoder, knownBy: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            format: try container.decodeIfPresent(String.self, forKey: .format),
            artworkSpin: try container.decodeIfPresent(Double.self, forKey: .artworkSpin)
        )
    }
}

public struct KamidanaBatteryIconConfig: Decodable, Equatable {
    public let chargingRightNow: String?
    public let capacity100: String?
    public let capacity90: String?
    public let capacity80: String?
    public let capacity70: String?
    public let capacity60: String?
    public let capacity50: String?
    public let capacity40: String?
    public let capacity30: String?
    public let capacity20: String?
    public let capacity10: String?
    public let sub10Charged: String?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case chargingRightNow = "charging_right_now"
        case capacity100 = "100_capacity"
        case capacity90 = "90_capacity"
        case capacity80 = "80_capacity"
        case capacity70 = "70_capacity"
        case capacity60 = "60_capacity"
        case capacity50 = "50_capacity"
        case capacity40 = "40_capacity"
        case capacity30 = "30_capacity"
        case capacity20 = "20_capacity"
        case capacity10 = "10_capacity"
        case sub10Charged = "sub_10_charged"
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(in: decoder, knownBy: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chargingRightNow = try container.decodeIfPresent(String.self, forKey: .chargingRightNow)
        capacity100 = try container.decodeIfPresent(String.self, forKey: .capacity100)
        capacity90 = try container.decodeIfPresent(String.self, forKey: .capacity90)
        capacity80 = try container.decodeIfPresent(String.self, forKey: .capacity80)
        capacity70 = try container.decodeIfPresent(String.self, forKey: .capacity70)
        capacity60 = try container.decodeIfPresent(String.self, forKey: .capacity60)
        capacity50 = try container.decodeIfPresent(String.self, forKey: .capacity50)
        capacity40 = try container.decodeIfPresent(String.self, forKey: .capacity40)
        capacity30 = try container.decodeIfPresent(String.self, forKey: .capacity30)
        capacity20 = try container.decodeIfPresent(String.self, forKey: .capacity20)
        capacity10 = try container.decodeIfPresent(String.self, forKey: .capacity10)
        sub10Charged = try container.decodeIfPresent(String.self, forKey: .sub10Charged)
    }
}

public struct KamidanaWeatherIconConfig: Codable, Equatable, Hashable {
    public let sun: String?
    public let cloud: String?
    public let rain: String?
    public let thunderRain: String?
    public let snow: String?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case sun, cloud, rain
        case thunderRain = "thunder_rain"
        case snow
    }

    public init(
        sun: String? = nil,
        cloud: String? = nil,
        rain: String? = nil,
        thunderRain: String? = nil,
        snow: String? = nil
    ) {
        self.sun = sun
        self.cloud = cloud
        self.rain = rain
        self.thunderRain = thunderRain
        self.snow = snow
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(in: decoder, knownBy: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            sun: try container.decodeIfPresent(String.self, forKey: .sun),
            cloud: try container.decodeIfPresent(String.self, forKey: .cloud),
            rain: try container.decodeIfPresent(String.self, forKey: .rain),
            thunderRain: try container.decodeIfPresent(String.self, forKey: .thunderRain),
            snow: try container.decodeIfPresent(String.self, forKey: .snow)
        )
    }
}

public struct KamidanaWeatherColorConfig: Codable, Equatable, Hashable {
    public let sun: String?
    public let cloud: String?
    public let rain: String?
    public let snow: String?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case sun, cloud, rain, snow
    }

    public init(
        sun: String? = nil,
        cloud: String? = nil,
        rain: String? = nil,
        snow: String? = nil
    ) {
        self.sun = sun
        self.cloud = cloud
        self.rain = rain
        self.snow = snow
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(in: decoder, knownBy: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            sun: try container.decodeIfPresent(String.self, forKey: .sun),
            cloud: try container.decodeIfPresent(String.self, forKey: .cloud),
            rain: try container.decodeIfPresent(String.self, forKey: .rain),
            snow: try container.decodeIfPresent(String.self, forKey: .snow)
        )
    }
}

public struct KamidanaWidget: Decodable, Equatable {
    public let id: String
    public let kind: KamidanaWidgetKind
    public var format: String?
    public var compactFormat: String?
    public var icon: String?
    public var polling: Double?
    public var weatherIcons: [KamidanaWeatherIconConfig]
    public var weatherColors: [KamidanaWeatherColorConfig]
    public var weatherDisplay: WeatherDisplayConfig?
    public var foldedIcon: String?
    public var direction: KamidanaWidgetFolderDirection?
    public var style: KamidanaStyle?
    public var popupStyle: KamidanaStyle?
    public var activate: KamidanaActivation?
    public var animation: KamidanaMotion?
    public var interval: Double?
    public var tooltip: Bool?
    public var tooltipFormat: String?
    public var widgets: [KamidanaWidget]
    public var actionChildren: [KamidanaSystemActionChild]
    public var batteryIcons: KamidanaBatteryIconConfig?
    public var partStyles: [String: KamidanaStyle]
    public var command: String?
    public var arguments: [String]
    public var width: Double?
    public var height: Double?
    public var barWidth: Double?
    public var padding: KamidanaInsets?
    public var inputManagement: Bool?
    public var outputManagement: Bool?
    public var gradientSeparation: Int?
    public var captureScope: KamidanaAudioVisualizerCaptureScope?
    public var channelMode: KamidanaAudioVisualizerChannelMode?
    public var separationLength: Int?
    public var smoothness: Double?
    public var formatOnAction: String?
    public var sliderChange: String?
    public var sliderPause: String?
    public var sliderBar: String?
    public var extend: KamidanaMusicExtendDirection?
    public var artworkSpin: Double?
    public var normal: KamidanaMusicNormalState?
    public var onAction: KamidanaMusicActionState?
    public var soundVisualizer: KamidanaSoundVisualizerConfig?

    public init(
        id: String,
        kind: KamidanaWidgetKind,
        format: String? = nil,
        compactFormat: String? = nil,
        icon: String? = nil,
        polling: Double? = nil,
        weatherIcons: [KamidanaWeatherIconConfig] = [],
        weatherColors: [KamidanaWeatherColorConfig] = [],
        weatherDisplay: WeatherDisplayConfig? = nil,
        foldedIcon: String? = nil,
        direction: KamidanaWidgetFolderDirection? = nil,
        style: KamidanaStyle? = nil,
        popupStyle: KamidanaStyle? = nil,
        activate: KamidanaActivation? = nil,
        animation: KamidanaMotion? = nil,
        interval: Double? = nil,
        tooltip: Bool? = nil,
        tooltipFormat: String? = nil,
        widgets: [KamidanaWidget] = [],
        actionChildren: [KamidanaSystemActionChild] = [],
        batteryIcons: KamidanaBatteryIconConfig? = nil,
        partStyles: [String: KamidanaStyle] = [:],
        command: String? = nil,
        arguments: [String] = [],
        width: Double? = nil,
        height: Double? = nil,
        barWidth: Double? = nil,
        padding: KamidanaInsets? = nil,
        inputManagement: Bool? = nil,
        outputManagement: Bool? = nil,
        gradientSeparation: Int? = nil,
        captureScope: KamidanaAudioVisualizerCaptureScope? = nil,
        channelMode: KamidanaAudioVisualizerChannelMode? = nil,
        separationLength: Int? = nil,
        smoothness: Double? = nil,
        formatOnAction: String? = nil,
        sliderChange: String? = nil,
        sliderPause: String? = nil,
        sliderBar: String? = nil,
        extend: KamidanaMusicExtendDirection? = nil,
        artworkSpin: Double? = nil,
        normal: KamidanaMusicNormalState? = nil,
        onAction: KamidanaMusicActionState? = nil,
        soundVisualizer: KamidanaSoundVisualizerConfig? = nil
    ) {
        self.id = id
        self.kind = kind
        self.format = format
        self.compactFormat = compactFormat
        self.icon = icon
        self.polling = polling
        self.weatherIcons = weatherIcons
        self.weatherColors = weatherColors
        self.weatherDisplay = weatherDisplay
        self.foldedIcon = foldedIcon
        self.direction = direction
        self.style = style
        self.popupStyle = popupStyle
        self.activate = activate
        self.animation = animation
        self.interval = interval
        self.tooltip = tooltip
        self.tooltipFormat = tooltipFormat
        self.widgets = widgets
        self.actionChildren = actionChildren
        self.batteryIcons = batteryIcons
        self.partStyles = partStyles
        self.command = command
        self.arguments = arguments
        self.width = width
        self.height = height
        self.barWidth = barWidth
        self.padding = padding
        self.inputManagement = inputManagement
        self.outputManagement = outputManagement
        self.gradientSeparation = gradientSeparation
        self.captureScope = captureScope
        self.channelMode = channelMode
        self.separationLength = separationLength
        self.smoothness = smoothness
        self.formatOnAction = formatOnAction
        self.sliderChange = sliderChange
        self.sliderPause = sliderPause
        self.sliderBar = sliderBar
        self.extend = extend
        self.artworkSpin = artworkSpin
        self.normal = normal
        self.onAction = onAction
        self.soundVisualizer = soundVisualizer
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(in: decoder, knownBy: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let type = try container.decode(String.self, forKey: .type)
        guard let kind = KamidanaWidgetKind(rawValue: type) else {
            throw KamidanaConfigurationV1Error.unsupportedWidgetType(type)
        }
        let direction = try container.decodeIfPresent(
            KamidanaWidgetFolderDirection.self,
            forKey: .direction
        )
        let inputManagement = try container.decodeIfPresent(Bool.self, forKey: .inputManagement)
        let outputManagement = try container.decodeIfPresent(Bool.self, forKey: .outputManagement)
        let gradientSeparation = try container.decodeIfPresent(
            Int.self, forKey: .gradientSeparation)
        let captureScope = try container.decodeIfPresent(
            KamidanaAudioVisualizerCaptureScope.self, forKey: .captureScope)
        let channelMode = try container.decodeIfPresent(
            KamidanaAudioVisualizerChannelMode.self, forKey: .channelMode)
        let separationLength = try container.decodeIfPresent(
            Int.self, forKey: .separationLength)
        let smoothness = try container.decodeIfPresent(Double.self, forKey: .smoothness)

        let regularIcon =
            kind == .battery || kind == .weather
            ? nil
            : try container.decodeIfPresent(String.self, forKey: .icon)
        let batteryIcons =
            kind == .battery
            ? try container.decodeIfPresent(KamidanaBatteryIconConfig.self, forKey: .icon)
            : nil
        let weatherIcons =
            kind == .weather
            ? try container.decodeIfPresent(
                [KamidanaWeatherIconConfig].self, forKey: .icon) ?? []
            : []
        let weatherColors =
            try container.decodeIfPresent(
                [KamidanaWeatherColorConfig].self, forKey: .color) ?? []

        self.init(
            id: id,
            kind: kind,
            format: try container.decodeIfPresent(String.self, forKey: .format),
            compactFormat: try container.decodeIfPresent(String.self, forKey: .compactFormat),
            icon: regularIcon,
            polling: try container.decodeIfPresent(Double.self, forKey: .polling),
            weatherIcons: weatherIcons,
            weatherColors: weatherColors,
            weatherDisplay: try container.decodeIfPresent(
                WeatherDisplayConfig.self, forKey: .weatherDisplay),
            foldedIcon: try container.decodeIfPresent(String.self, forKey: .foldedIcon),
            direction: kind == .widgetFolder ? direction ?? .below : direction,
            style: try container.decodeIfPresent(KamidanaStyle.self, forKey: .style),
            popupStyle: try container.decodeIfPresent(KamidanaStyle.self, forKey: .popupStyle),
            activate: try container.decodeIfPresent(KamidanaActivation.self, forKey: .activate),
            animation: try container.decodeIfPresent(KamidanaMotion.self, forKey: .animation),
            interval: try container.decodeIfPresent(Double.self, forKey: .interval),
            tooltip: try container.decodeIfPresent(Bool.self, forKey: .tooltip),
            tooltipFormat: try container.decodeIfPresent(String.self, forKey: .tooltipFormat),
            widgets: try container.decodeIfPresent([KamidanaWidget].self, forKey: .widgets) ?? [],
            actionChildren: try container.decodeIfPresent(
                [KamidanaSystemActionChild].self, forKey: .children) ?? [],
            batteryIcons: batteryIcons,
            partStyles: try container.decodeIfPresent(
                [String: KamidanaStyle].self, forKey: .partStyles)
                ?? [:],
            command: try container.decodeIfPresent(String.self, forKey: .command),
            arguments: try container.decodeIfPresent([String].self, forKey: .arguments) ?? [],
            width: try container.decodeIfPresent(Double.self, forKey: .width),
            height: try container.decodeIfPresent(Double.self, forKey: .height),
            barWidth: try container.decodeIfPresent(Double.self, forKey: .barWidth),
            padding: try container.decodeIfPresent(KamidanaInsets.self, forKey: .padding),
            inputManagement: kind == .volume ? inputManagement ?? true : inputManagement,
            outputManagement: kind == .volume ? outputManagement ?? true : outputManagement,
            gradientSeparation: kind == .audioVisualizer
                ? gradientSeparation ?? 1 : gradientSeparation,
            captureScope: kind == .audioVisualizer
                ? captureScope ?? .system : captureScope,
            channelMode: kind == .audioVisualizer
                ? channelMode ?? .stereo : channelMode,
            separationLength: kind == .audioVisualizer
                ? separationLength ?? 5 : separationLength,
            smoothness: kind == .audioVisualizer
                ? smoothness ?? 0.5 : smoothness,
            formatOnAction: try container.decodeIfPresent(String.self, forKey: .formatOnAction),
            sliderChange: try container.decodeIfPresent(String.self, forKey: .sliderChange),
            sliderPause: try container.decodeIfPresent(String.self, forKey: .sliderPause),
            sliderBar: try container.decodeIfPresent(String.self, forKey: .sliderBar),
            extend: try container.decodeIfPresent(
                KamidanaMusicExtendDirection.self, forKey: .extend),
            artworkSpin: try container.decodeIfPresent(Double.self, forKey: .artworkSpin),
            normal: try container.decodeIfPresent(KamidanaMusicNormalState.self, forKey: .normal),
            onAction: try container.decodeIfPresent(
                KamidanaMusicActionState.self, forKey: .onAction),
            soundVisualizer: try container.decodeIfPresent(
                KamidanaSoundVisualizerConfig.self, forKey: .soundVisualizer)
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id, type, format
        case compactFormat = "compact_format"
        case icon
        case foldedIcon = "folded_icon"
        case direction
        case style
        case popupStyle = "popup_style"
        case activate, animation, interval, polling, tooltip
        case weatherDisplay = "weather_display"
        case tooltipFormat = "tooltip_format"
        case widgets, children, color
        case partStyles = "part_styles"
        case command, arguments, width, height
        case barWidth = "bar_width"
        case padding
        case inputManagement = "input_management"
        case outputManagement = "output_management"
        case gradientSeparation = "gradient_separation"
        case captureScope = "capture_scope"
        case channelMode = "channel_mode"
        case separationLength = "separation_length"
        case smoothness
        case formatOnAction = "format_on_action"
        case sliderChange = "slider_change"
        case sliderPause = "slider_pause"
        case sliderBar = "slider_bar"
        case extend
        case artworkSpin = "artwork_spin"
        case normal
        case onAction = "on_action"
        case soundVisualizer = "sound_visualizer"
    }
}

public struct KamidanaConfigurationV1Global: Decodable, Equatable {
    public var lang: String
    public var backgroundMode: KamidanaBackgroundMode
    public var hideInFullscreen: Bool
    public var launchAtLogin: Bool
    public var displayTargets: [KamidanaDisplayTarget]
    public var style: KamidanaStyle
    public var popupStyle: KamidanaStyle?
    public var barPadding: KamidanaInsets

    public init(
        lang: String = "en",
        backgroundMode: KamidanaBackgroundMode = .singleBar,
        hideInFullscreen: Bool = false,
        launchAtLogin: Bool = false,
        displayTargets: [KamidanaDisplayTarget] = [KamidanaDisplayTarget(kind: .primary)],
        style: KamidanaStyle = KamidanaStyle(),
        popupStyle: KamidanaStyle? = nil,
        barPadding: KamidanaInsets = KamidanaInsets()
    ) {
        self.lang = lang
        self.backgroundMode = backgroundMode
        self.hideInFullscreen = hideInFullscreen
        self.launchAtLogin = launchAtLogin
        self.displayTargets = displayTargets
        self.style = style
        self.popupStyle = popupStyle
        self.barPadding = barPadding
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case lang
        case backgroundMode = "background_mode"
        case hideInFullscreen = "hide_in_fullscreen"
        case launchAtLogin = "launch_at_login"
        case displayTargets = "display_targets"
        case style
        case popupStyle = "popup_style"
        case barPadding = "bar_padding"
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(in: decoder, knownBy: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let displayTargets =
            try container.decodeIfPresent(
                [KamidanaDisplayTarget].self, forKey: .displayTargets
            ) ?? [KamidanaDisplayTarget(kind: .primary)]
        guard !displayTargets.isEmpty else {
            throw KamidanaConfigurationV1Error.invalidDisplayTarget(
                path: "global.display_targets", reason: "at least one target is required"
            )
        }
        for (index, target) in displayTargets.enumerated() {
            try target.validate(path: "global.display_targets[\(index)]")
        }
        self.init(
            lang: try container.decodeIfPresent(String.self, forKey: .lang) ?? "en",
            backgroundMode: try container.decodeIfPresent(
                KamidanaBackgroundMode.self, forKey: .backgroundMode) ?? .singleBar,
            hideInFullscreen: try container.decodeIfPresent(Bool.self, forKey: .hideInFullscreen)
                ?? false,
            launchAtLogin: try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin)
                ?? false,
            displayTargets: displayTargets,
            style: try container.decodeIfPresent(KamidanaStyle.self, forKey: .style)
                ?? KamidanaStyle(),
            popupStyle: try container.decodeIfPresent(KamidanaStyle.self, forKey: .popupStyle),
            barPadding: try container.decodeIfPresent(KamidanaInsets.self, forKey: .barPadding)
                ?? KamidanaInsets()
        )
    }
}

public struct KamidanaConfigurationV1Section: Decodable, Equatable {
    public var backgroundMode: KamidanaBackgroundMode?
    public var activate: KamidanaActivation?
    public var animation: KamidanaMotion?
    public var style: KamidanaStyle
    public var popupStyle: KamidanaStyle?
    public var widgets: [KamidanaWidget]

    public init(
        backgroundMode: KamidanaBackgroundMode? = nil,
        activate: KamidanaActivation? = nil,
        animation: KamidanaMotion? = nil,
        style: KamidanaStyle = KamidanaStyle(),
        popupStyle: KamidanaStyle? = nil,
        widgets: [KamidanaWidget] = []
    ) {
        self.backgroundMode = backgroundMode
        self.activate = activate
        self.animation = animation
        self.style = style
        self.popupStyle = popupStyle
        self.widgets = widgets
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case backgroundMode = "background_mode"
        case activate, animation, style, widgets
        case popupStyle = "popup_style"
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(in: decoder, knownBy: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            backgroundMode: try container.decodeIfPresent(
                KamidanaBackgroundMode.self, forKey: .backgroundMode),
            activate: try container.decodeIfPresent(KamidanaActivation.self, forKey: .activate),
            animation: try container.decodeIfPresent(KamidanaMotion.self, forKey: .animation),
            style: try container.decodeIfPresent(KamidanaStyle.self, forKey: .style)
                ?? KamidanaStyle(),
            popupStyle: try container.decodeIfPresent(KamidanaStyle.self, forKey: .popupStyle),
            widgets: try container.decodeIfPresent([KamidanaWidget].self, forKey: .widgets) ?? []
        )
    }
}

public struct KamidanaConfigurationV1Center: Decodable, Equatable {
    public var backgroundMode: KamidanaBackgroundMode?
    public var activate: KamidanaActivation?
    public var style: KamidanaStyle
    public var popupStyle: KamidanaStyle?
    public var centerDefault: String
    public var widgets: [KamidanaWidget]

    public init(
        backgroundMode: KamidanaBackgroundMode? = nil,
        activate: KamidanaActivation? = nil,
        style: KamidanaStyle = KamidanaStyle(),
        popupStyle: KamidanaStyle? = nil,
        centerDefault: String,
        widgets: [KamidanaWidget]
    ) {
        self.backgroundMode = backgroundMode
        self.activate = activate
        self.style = style
        self.popupStyle = popupStyle
        self.centerDefault = centerDefault
        self.widgets = widgets
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case backgroundMode = "background_mode"
        case activate, style
        case popupStyle = "popup_style"
        case centerDefault = "center_default"
        case widgets
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(in: decoder, knownBy: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            backgroundMode: try container.decodeIfPresent(
                KamidanaBackgroundMode.self, forKey: .backgroundMode),
            activate: try container.decodeIfPresent(KamidanaActivation.self, forKey: .activate),
            style: try container.decodeIfPresent(KamidanaStyle.self, forKey: .style)
                ?? KamidanaStyle(),
            popupStyle: try container.decodeIfPresent(KamidanaStyle.self, forKey: .popupStyle),
            centerDefault: try container.decode(String.self, forKey: .centerDefault),
            widgets: try container.decode([KamidanaWidget].self, forKey: .widgets)
        )
    }
}

public struct KamidanaConfigurationV1: Decodable, Equatable {
    public var global: KamidanaConfigurationV1Global
    public var left: KamidanaConfigurationV1Section
    public var center: KamidanaConfigurationV1Center
    public var right: KamidanaConfigurationV1Section

    public init(
        global: KamidanaConfigurationV1Global,
        left: KamidanaConfigurationV1Section,
        center: KamidanaConfigurationV1Center,
        right: KamidanaConfigurationV1Section
    ) {
        self.global = global
        self.left = left
        self.center = center
        self.right = right
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case global, left, center, right
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(in: decoder, knownBy: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            global: try container.decodeIfPresent(
                KamidanaConfigurationV1Global.self, forKey: .global)
                ?? KamidanaConfigurationV1Global(),
            left: try container.decodeIfPresent(KamidanaConfigurationV1Section.self, forKey: .left)
                ?? KamidanaConfigurationV1Section(),
            center: try container.decode(KamidanaConfigurationV1Center.self, forKey: .center),
            right: try container.decodeIfPresent(
                KamidanaConfigurationV1Section.self, forKey: .right)
                ?? KamidanaConfigurationV1Section()
        )
    }

    /// Validates cross-widget rules and typed style ranges after decoding.
    public func validate() throws {
        try validateGlobal(global)
        try validateSection(left, name: "left")
        try validateCenter(center)
        try validateSection(right, name: "right")

        var ids = Set<String>()
        try collectIDs(left.widgets, ids: &ids)
        try collectIDs(center.widgets, ids: &ids)
        try collectIDs(right.widgets, ids: &ids)
    }

    private func validateGlobal(_ global: KamidanaConfigurationV1Global) throws {
        guard !global.lang.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw KamidanaConfigurationV1Error.invalidDisplayTarget(
                path: "global.lang", reason: "lang must be non-empty")
        }
        try validateStyle(global.style, path: "global.style")
        try global.popupStyle.map { try validateStyle($0, path: "global.popup_style") }
        try validateInsets(global.barPadding, path: "global.bar_padding")
        guard !global.displayTargets.isEmpty else {
            throw KamidanaConfigurationV1Error.invalidDisplayTarget(
                path: "global.display_targets", reason: "at least one target is required"
            )
        }
        for (index, target) in global.displayTargets.enumerated() {
            try target.validate(path: "global.display_targets[\(index)]")
        }
    }

    private func validateSection(_ section: KamidanaConfigurationV1Section, name: String) throws {
        try validateStyle(section.style, path: "\(name).style")
        try section.popupStyle.map { try validateStyle($0, path: "\(name).popup_style") }
        try validateWidgets(
            section.widgets, section: name, path: "\(name).widgets", isTopLevel: true)
    }

    private func validateCenter(_ section: KamidanaConfigurationV1Center) throws {
        try validateStyle(section.style, path: "center.style")
        try section.popupStyle.map { try validateStyle($0, path: "center.popup_style") }
        guard !section.centerDefault.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw KamidanaConfigurationV1Error.invalidCenterDefault(section.centerDefault)
        }

        try validateWidgets(
            section.widgets, section: "center", path: "center.widgets", isTopLevel: true)
        guard let defaultWidget = section.widgets.first(where: { $0.id == section.centerDefault })
        else {
            throw KamidanaConfigurationV1Error.invalidCenterDefault(section.centerDefault)
        }
        let defaultFormat =
            defaultWidget.compactFormat
            ?? defaultWidget.normal?.format
            ?? defaultWidget.format
        guard let defaultFormat,
            !defaultFormat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw KamidanaConfigurationV1Error.centerDefaultRequiresCompactFormat(
                section.centerDefault)
        }
    }

    private func validateWidgets(
        _ widgets: [KamidanaWidget],
        section: String,
        path: String,
        isTopLevel: Bool
    ) throws {
        for (index, widget) in widgets.enumerated() {
            let widgetPath = "\(path)[\(index)]"
            if widget.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw KamidanaConfigurationV1Error.invalidWidget(
                    path: widgetPath, reason: "id must be non-empty")
            }
            if let interval = widget.interval, interval <= 0 || !interval.isFinite {
                throw KamidanaConfigurationV1Error.invalidWidget(
                    path: widgetPath, reason: "interval must be positive")
            }
            if let polling = widget.polling, polling <= 0 || !polling.isFinite {
                throw KamidanaConfigurationV1Error.invalidWidget(
                    path: widgetPath, reason: "polling must be positive")
            }
            if let width = widget.width, width <= 0 || !width.isFinite {
                throw KamidanaConfigurationV1Error.invalidWidget(
                    path: widgetPath, reason: "width must be positive")
            }
            if let height = widget.height, height <= 0 || !height.isFinite {
                throw KamidanaConfigurationV1Error.invalidWidget(
                    path: widgetPath, reason: "height must be positive")
            }
            if widget.kind == .custom,
                widget.command?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
            {
                throw KamidanaConfigurationV1Error.emptyCustomCommand(widgetPath)
            }
            if widget.kind == .btop && (section != "center" || !isTopLevel) {
                throw KamidanaConfigurationV1Error.btopMustBeInCenter(widget.id)
            }

            try validateKindSpecificFields(widget, section: section, path: widgetPath)

            let tooltipFieldsArePresent = widget.tooltip != nil || widget.tooltipFormat != nil
            if tooltipFieldsArePresent && ![.cpu, .gpu, .memory, .network].contains(widget.kind) {
                throw KamidanaConfigurationV1Error.tooltipNotAllowed(widgetPath)
            }
            if widget.tooltip == true,
                widget.tooltipFormat?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    != false
            {
                throw KamidanaConfigurationV1Error.tooltipFormatRequired(widgetPath)
            }
            try widget.style.map { try validateStyle($0, path: "\(widgetPath).style") }
            try widget.popupStyle.map { try validateStyle($0, path: "\(widgetPath).popup_style") }
            for (part, style) in widget.partStyles {
                try validateStyle(style, path: "\(widgetPath).part_styles.\(part)")
            }
            try validateWidgets(
                widget.widgets,
                section: section,
                path: "\(widgetPath).widgets",
                isTopLevel: false
            )
            try validateActionChildren(widget.actionChildren, path: "\(widgetPath).children")
        }
    }

    private func validateKindSpecificFields(
        _ widget: KamidanaWidget,
        section: String,
        path: String
    ) throws {
        if widget.kind != .btop && widget.kind != .music && widget.kind != .audioVisualizer
            && (widget.width != nil || widget.height != nil)
        {
            throw KamidanaConfigurationV1Error.invalidWidget(
                path: path,
                reason: "width and height are valid only for btop, music, and audio-visualizer"
            )
        }
        if widget.kind != .audioVisualizer && widget.barWidth != nil {
            throw KamidanaConfigurationV1Error.invalidWidget(
                path: path, reason: "bar_width is valid only for audio-visualizer"
            )
        }
        if widget.kind != .audioVisualizer && widget.padding != nil {
            throw KamidanaConfigurationV1Error.invalidWidget(
                path: path, reason: "padding is valid only for audio-visualizer"
            )
        }
        if widget.kind == .widgetFolder && widget.widgets.isEmpty {
            throw KamidanaConfigurationV1Error.invalidWidget(
                path: path,
                reason: "widget-folder must contain at least one widget"
            )
        } else if widget.kind != .widgetFolder && widget.widgets.isEmpty == false {
            throw KamidanaConfigurationV1Error.invalidWidget(
                path: path,
                reason: "widgets is valid only for widget-folder"
            )
        }

        if widget.kind == .widgetFolder && widget.direction == .below,
            let expandingChild = widget.widgets.first(where: isExpandingWidget)
        {
            throw KamidanaConfigurationV1Error.invalidWidget(
                path: path,
                reason:
                    "below widget-folder cannot contain expanding widget '\(expandingChild.id)'"
            )
        }

        if widget.kind == .systemAction {
            if widget.actionChildren.isEmpty {
                throw KamidanaConfigurationV1Error.invalidWidget(
                    path: path,
                    reason: "system-action must contain at least one child"
                )
            }
        } else if widget.actionChildren.isEmpty == false {
            throw KamidanaConfigurationV1Error.invalidWidget(
                path: path,
                reason: "children is valid only for system-action"
            )
        }

        if widget.kind != .widgetFolder && widget.kind != .systemAction {
            if widget.icon != nil {
                throw KamidanaConfigurationV1Error.invalidWidget(
                    path: path,
                    reason:
                        "icon is valid only for widget-folder and system-action; include Nerd Font icons in format for regular widgets"
                )
            }
            if widget.foldedIcon != nil {
                throw KamidanaConfigurationV1Error.invalidWidget(
                    path: path,
                    reason: "folded_icon is valid only for widget-folder and system-action"
                )
            }
            if widget.direction != nil {
                throw KamidanaConfigurationV1Error.invalidWidget(
                    path: path,
                    reason: "direction is valid only for widget-folder"
                )
            }
        }

        if widget.kind == .systemAction && widget.direction != nil {
            throw KamidanaConfigurationV1Error.invalidWidget(
                path: path,
                reason: "system-action always expands below and does not accept direction"
            )
        }

        if widget.kind != .custom && (widget.command != nil || widget.arguments.isEmpty == false) {
            throw KamidanaConfigurationV1Error.invalidWidget(
                path: path,
                reason: "command and arguments are valid only for custom"
            )
        }

        if ![.music, .volume].contains(widget.kind) && widget.partStyles.isEmpty == false {
            throw KamidanaConfigurationV1Error.invalidWidget(
                path: path,
                reason: "part_styles is valid only for music and volume"
            )
        }

        if widget.kind != .volume
            && (widget.inputManagement != nil || widget.outputManagement != nil)
        {
            throw KamidanaConfigurationV1Error.invalidWidget(
                path: path,
                reason: "input_management and output_management are valid only for volume"
            )
        }

        let hasAudioVisualizerConfiguration =
            widget.gradientSeparation != nil
            || widget.captureScope != nil
            || widget.channelMode != nil
            || widget.separationLength != nil
            || widget.smoothness != nil
            || widget.barWidth != nil
        if widget.kind != .audioVisualizer && hasAudioVisualizerConfiguration {
            throw KamidanaConfigurationV1Error.invalidWidget(
                path: path,
                reason:
                    "gradient_separation, capture_scope, channel_mode, separation_length, smoothness, and bar_width are valid only for audio-visualizer"
            )
        }

        if widget.kind == .audioVisualizer {
            if let height = widget.height,
                height.rounded() != height || height < 1 || height > 100
            {
                throw KamidanaConfigurationV1Error.invalidWidget(
                    path: path, reason: "height must be an integer in 1...100"
                )
            }
            if let barWidth = widget.barWidth, barWidth <= 0 || !barWidth.isFinite {
                throw KamidanaConfigurationV1Error.invalidWidget(
                    path: path, reason: "bar_width must be positive"
                )
            }
            if let padding = widget.padding {
                let values = [padding.top, padding.bottom, padding.leading, padding.trailing]
                if values.contains(where: { $0 < 0 || !$0.isFinite }) {
                    throw KamidanaConfigurationV1Error.invalidWidget(
                        path: path, reason: "padding values must be non-negative"
                    )
                }
            }
            let maximumGradientSeparation = section == "center" ? 5 : 2
            let gradientSeparation = widget.gradientSeparation ?? 1
            if gradientSeparation < 1 || gradientSeparation > maximumGradientSeparation {
                throw KamidanaConfigurationV1Error.invalidWidget(
                    path: path,
                    reason:
                        "gradient_separation must be in 1...\(maximumGradientSeparation) for the \(section) section"
                )
            }

            let separationLength = widget.separationLength ?? 5
            if separationLength < 1 || separationLength > 20 {
                throw KamidanaConfigurationV1Error.invalidWidget(
                    path: path, reason: "separation_length must be in 1...20"
                )
            }

            let smoothness = widget.smoothness ?? 0.5
            if smoothness < 0 || smoothness > 1 || !smoothness.isFinite {
                throw KamidanaConfigurationV1Error.invalidWidget(
                    path: path, reason: "smoothness must be in 0...1"
                )
            }

            for (name, format) in [
                ("format", widget.format),
                ("compact_format", widget.compactFormat),
            ] {
                if let format {
                    let placeholderCount = format.components(separatedBy: "{display}").count - 1
                    if placeholderCount != 1 {
                        throw KamidanaConfigurationV1Error.invalidWidget(
                            path: path,
                            reason: "\(name) must contain exactly one {display} placeholder"
                        )
                    }
                }
            }
        }

        if widget.kind != .weather
            && (widget.polling != nil || !widget.weatherIcons.isEmpty
                || !widget.weatherColors.isEmpty || widget.weatherDisplay != nil)
        {
            throw KamidanaConfigurationV1Error.invalidWidget(
                path: path,
                reason:
                    "polling, weather icon/color maps, and weather_display are valid only for weather"
            )
        }

        try widget.weatherDisplay?.validate(path: "\(path).weather_display")

        let hasMusicConfiguration =
            widget.formatOnAction != nil
            || widget.sliderChange != nil
            || widget.sliderPause != nil
            || widget.sliderBar != nil
            || widget.extend != nil
            || widget.artworkSpin != nil
            || widget.normal != nil
            || widget.onAction != nil
            || widget.soundVisualizer != nil
        if widget.kind != .music && hasMusicConfiguration {
            throw KamidanaConfigurationV1Error.invalidWidget(
                path: path,
                reason:
                    "format_on_action, slider colors, extend, artwork_spin, normal, on_action, and sound_visualizer are valid only for music"
            )
        }

        if widget.kind == .music {
            try validateOptionalFormat(widget.formatOnAction, name: "format_on_action", path: path)
            try validateOptionalFormat(widget.normal?.format, name: "normal.format", path: path)
            try validateOptionalFormat(
                widget.normal?.formatOnAction,
                name: "normal.format_on_action",
                path: path
            )
            try validateOptionalFormat(
                widget.onAction?.format, name: "on_action.format", path: path)
            try validateArtworkSpin(widget.artworkSpin, name: "artwork_spin", path: path)
            try validateArtworkSpin(
                widget.normal?.artworkSpin,
                name: "normal.artwork_spin",
                path: path
            )
            try validateArtworkSpin(
                widget.onAction?.artworkSpin,
                name: "on_action.artwork_spin",
                path: path
            )

            if let visualizer = widget.soundVisualizer {
                if visualizer.height < 1 || visualizer.height > 100 {
                    throw KamidanaConfigurationV1Error.invalidWidget(
                        path: path,
                        reason: "sound_visualizer.height must be in 1...100"
                    )
                }
                if visualizer.barWidth <= 0 || !visualizer.barWidth.isFinite {
                    throw KamidanaConfigurationV1Error.invalidWidget(
                        path: path,
                        reason: "sound_visualizer.bar_width must be positive"
                    )
                }
                let paddingValues = [
                    visualizer.padding.top,
                    visualizer.padding.bottom,
                    visualizer.padding.leading,
                    visualizer.padding.trailing,
                ]
                if paddingValues.contains(where: { $0 < 0 || !$0.isFinite }) {
                    throw KamidanaConfigurationV1Error.invalidWidget(
                        path: path,
                        reason: "sound_visualizer.padding values must be non-negative"
                    )
                }
                let maximumGradientSeparation = section == "center" ? 5 : 2
                if visualizer.gradientSeparation < 1
                    || visualizer.gradientSeparation > maximumGradientSeparation
                {
                    throw KamidanaConfigurationV1Error.invalidWidget(
                        path: path,
                        reason:
                            "sound_visualizer.gradient_separation must be in 1...\(maximumGradientSeparation) for the \(section) section"
                    )
                }
                let maximumSeparationLength = section == "center" ? 30 : 20
                if visualizer.separationLength < 1
                    || visualizer.separationLength > maximumSeparationLength
                {
                    throw KamidanaConfigurationV1Error.invalidWidget(
                        path: path,
                        reason:
                            "sound_visualizer.separation_length must be in 1...\(maximumSeparationLength)"
                    )
                }

                if visualizer.smoothness < 0
                    || visualizer.smoothness > 1
                    || !visualizer.smoothness.isFinite
                {
                    throw KamidanaConfigurationV1Error.invalidWidget(
                        path: path,
                        reason: "sound_visualizer.smoothness must be in 0...1"
                    )
                }
                let placeholderCount =
                    visualizer.format.components(separatedBy: "{display}").count - 1
                if placeholderCount != 1 {
                    throw KamidanaConfigurationV1Error.invalidWidget(
                        path: path,
                        reason:
                            "sound_visualizer.format must contain exactly one {display} placeholder"
                    )
                }
                try validateStyle(visualizer.style, path: "\(path).sound_visualizer.style")
            }
        }
    }

    private func validateOptionalFormat(_ format: String?, name: String, path: String) throws {
        if let format, format.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw KamidanaConfigurationV1Error.invalidWidget(
                path: path,
                reason: "\(name) must be non-empty"
            )
        }
    }

    private func validateArtworkSpin(_ duration: Double?, name: String, path: String) throws {
        if let duration, duration < 0 || !duration.isFinite {
            throw KamidanaConfigurationV1Error.invalidWidget(
                path: path,
                reason: "\(name) must be zero or a positive number of seconds"
            )
        }
    }

    private func isExpandingWidget(_ widget: KamidanaWidget) -> Bool {
        if [.music, .volume, .network, .bluetooth, .weather, .widgetFolder, .systemAction].contains(
            widget.kind)
        {
            return true
        }
        return widget.activate != nil || widget.tooltip == true
    }

    private func validateActionChildren(_ children: [KamidanaSystemActionChild], path: String)
        throws
    {
        for (index, child) in children.enumerated() {
            let childPath = "\(path)[\(index)]"
            guard !child.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw KamidanaConfigurationV1Error.invalidWidget(
                    path: childPath, reason: "id must be non-empty")
            }
            guard !child.format.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw KamidanaConfigurationV1Error.invalidWidget(
                    path: childPath, reason: "format must be non-empty")
            }
            guard !child.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw KamidanaConfigurationV1Error.invalidWidget(
                    path: childPath, reason: "icon must be non-empty")
            }
            try validateStyle(child.style, path: "\(childPath).style")
        }
    }

    private func validateStyle(_ style: KamidanaStyle, path: String) throws {
        func nonNegative(_ value: Double?, _ name: String) throws {
            if let value, value < 0 || !value.isFinite {
                throw KamidanaConfigurationV1Error.invalidStyle(
                    path: path, reason: "\(name) must be non-negative")
            }
        }
        if let opacity = style.opacity, opacity < 0 || opacity > 1 || !opacity.isFinite {
            throw KamidanaConfigurationV1Error.invalidStyle(
                path: path, reason: "opacity must be in 0...1")
        }
        try nonNegative(style.spacing, "spacing")
        try nonNegative(style.cornerRadius, "corner_radius")
        if let padding = style.padding {
            try nonNegative(padding.top, "padding.top")
            try nonNegative(padding.bottom, "padding.bottom")
            try nonNegative(padding.leading, "padding.leading")
            try nonNegative(padding.trailing, "padding.trailing")
        }
        if let border = style.border {
            try nonNegative(border.width, "border.width")
        }
        if let shadow = style.shadow {
            try nonNegative(shadow.radius, "shadow.radius")
            try nonNegative(shadow.opacity, "shadow.opacity")
            if shadow.opacity > 1 {
                throw KamidanaConfigurationV1Error.invalidStyle(
                    path: path, reason: "shadow.opacity must be in 0...1")
            }
        }
        if let animation = style.animation {
            try nonNegative(animation.durationSeconds, "animation.duration_seconds")
            try nonNegative(animation.response, "animation.response")
            try nonNegative(animation.blendDuration, "animation.blend_duration")
            if let damping = animation.damping, damping < 0 || damping > 1 || !damping.isFinite {
                throw KamidanaConfigurationV1Error.invalidStyle(
                    path: path, reason: "animation.damping must be in 0...1")
            }
        }
        for (state, override) in style.states {
            try validateStyle(override, path: "\(path).states.\(state)")
        }
    }

    private func validateInsets(_ insets: KamidanaInsets, path: String) throws {
        func nonNegative(_ value: Double, _ name: String) throws {
            if value < 0 || !value.isFinite {
                throw KamidanaConfigurationV1Error.invalidStyle(
                    path: path, reason: "\(name) must be non-negative"
                )
            }
        }

        try nonNegative(insets.top, "padding.top")
        try nonNegative(insets.bottom, "padding.bottom")
        try nonNegative(insets.leading, "padding.leading")
        try nonNegative(insets.trailing, "padding.trailing")
    }

    private func collectIDs(_ widgets: [KamidanaWidget], ids: inout Set<String>) throws {
        for widget in widgets {
            guard ids.insert(widget.id).inserted else {
                throw KamidanaConfigurationV1Error.duplicateID(widget.id)
            }
            try collectIDs(widget.widgets, ids: &ids)
            for child in widget.actionChildren {
                guard ids.insert(child.id).inserted else {
                    throw KamidanaConfigurationV1Error.duplicateID(child.id)
                }
            }
        }
    }
}

/// The monitor-specific layout, without the shared global settings.
public struct KamidanaDisplayConfigurationV1: Decodable, Equatable {
    public var left: KamidanaConfigurationV1Section
    public var center: KamidanaConfigurationV1Center
    public var right: KamidanaConfigurationV1Section

    public init(
        left: KamidanaConfigurationV1Section = KamidanaConfigurationV1Section(),
        center: KamidanaConfigurationV1Center,
        right: KamidanaConfigurationV1Section = KamidanaConfigurationV1Section()
    ) {
        self.left = left
        self.center = center
        self.right = right
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case left, center, right
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(in: decoder, knownBy: CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            left: try container.decodeIfPresent(KamidanaConfigurationV1Section.self, forKey: .left)
                ?? KamidanaConfigurationV1Section(),
            center: try container.decode(KamidanaConfigurationV1Center.self, forKey: .center),
            right: try container.decodeIfPresent(
                KamidanaConfigurationV1Section.self, forKey: .right)
                ?? KamidanaConfigurationV1Section()
        )
    }

    fileprivate func configuration(global: KamidanaConfigurationV1Global) -> KamidanaConfigurationV1
    {
        KamidanaConfigurationV1(global: global, left: left, center: center, right: right)
    }
}

struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = String(intValue)
    }
}

/// Contains the complete UI configuration for both display classes in one file.
/// `global` is deliberately shared: monitor-specific sections contain layout only.
public struct KamidanaMonitorConfigurationV1: Decodable, Equatable {
    public var global: KamidanaConfigurationV1Global
    public var displays: [String: KamidanaConfigurationV1]

    public init(
        global: KamidanaConfigurationV1Global,
        displays: [String: KamidanaConfigurationV1]
    ) {
        self.global = global
        self.displays = displays
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)

        let globalKey = AnyCodingKey(stringValue: "global")!
        let global =
            try container.decodeIfPresent(KamidanaConfigurationV1Global.self, forKey: globalKey)
            ?? KamidanaConfigurationV1Global()

        var parsedDisplays: [String: KamidanaConfigurationV1] = [:]

        for key in container.allKeys {
            if key.stringValue == "global" { continue }

            let displayConfig = try container.decode(
                KamidanaDisplayConfigurationV1.self, forKey: key)
            parsedDisplays[key.stringValue] = displayConfig.configuration(global: global)
        }

        self.global = global
        self.displays = parsedDisplays
    }

    public func validate() throws {
        for display in displays.values {
            try display.validate()
        }
    }
}

/// Yams-backed entry point for monitor-specific configuration strings.
public struct KamidanaMonitorConfigurationV1Decoder {
    public init() {}

    public static func decode(yaml: String) throws -> KamidanaMonitorConfigurationV1 {
        do {
            let configuration = try YAMLDecoder().decode(
                KamidanaMonitorConfigurationV1.self, from: yaml)
            try configuration.validate()
            return configuration
        } catch let error as KamidanaConfigurationV1Error {
            throw error
        } catch {
            let message = String(describing: error)
            if let displayTargetError = displayTargetError(in: message) {
                throw displayTargetError
            }
            if let marker = message.range(of: "Unsupported widget type '") {
                let remainder = message[marker.upperBound...]
                if let end = remainder.firstIndex(of: "'") {
                    throw KamidanaConfigurationV1Error.unsupportedWidgetType(
                        String(remainder[..<end]))
                }
            }
            throw KamidanaConfigurationV1Error.yamlDecoding(message)
        }
    }

    public func decode(yaml: String) throws -> KamidanaMonitorConfigurationV1 {
        try Self.decode(yaml: yaml)
    }
}

/// Yams-backed entry point for v1 configuration strings.
public struct KamidanaConfigurationV1Decoder {
    public init() {}

    public static func decode(yaml: String) throws -> KamidanaConfigurationV1 {
        do {
            let configuration = try YAMLDecoder().decode(KamidanaConfigurationV1.self, from: yaml)
            try configuration.validate()
            return configuration
        } catch let error as KamidanaConfigurationV1Error {
            throw error
        } catch {
            let message = String(describing: error)
            if let displayTargetError = displayTargetError(in: message) {
                throw displayTargetError
            }
            if let marker = message.range(of: "Unsupported widget type '") {
                let remainder = message[marker.upperBound...]
                if let end = remainder.firstIndex(of: "'") {
                    throw KamidanaConfigurationV1Error.unsupportedWidgetType(
                        String(remainder[..<end]))
                }
            }
            throw KamidanaConfigurationV1Error.yamlDecoding(String(describing: error))
        }
    }

    public func decode(yaml: String) throws -> KamidanaConfigurationV1 {
        try Self.decode(yaml: yaml)
    }
}
