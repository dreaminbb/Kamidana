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

  throw DecodingError.dataCorruptedError(
    forKey: unknownKey,
    in: container,
    debugDescription: "Unknown configuration key '\(unknownKey.stringValue)'."
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
      opacity: try container.decodeIfPresent(Double.self, forKey: .opacity),
      padding: try container.decodeIfPresent(KamidanaInsets.self, forKey: .padding),
      spacing: try container.decodeIfPresent(Double.self, forKey: .spacing),
      cornerRadius: try container.decodeIfPresent(Double.self, forKey: .cornerRadius),
      border: try container.decodeIfPresent(KamidanaBorder.self, forKey: .border),
      shadow: try container.decodeIfPresent(KamidanaShadow.self, forKey: .shadow),
      material: try container.decodeIfPresent(KamidanaMaterial.self, forKey: .material),
      animation: try container.decodeIfPresent(KamidanaAnimation.self, forKey: .animation),
      states: try container.decodeIfPresent([String: KamidanaStyle].self, forKey: .states) ?? [:]
    )
  }
}

public enum KamidanaWidgetKind: String, Codable, Equatable, CaseIterable {
  case music
  case volume
  case cpu
  case gpu
  case memory
  case network
  case disk
  case battery
  case clock
  case bluetooth
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
      style: try container.decodeIfPresent(KamidanaStyle.self, forKey: .style) ?? KamidanaStyle()
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
      extend: try container.decodeIfPresent(KamidanaMusicExtendDirection.self, forKey: .extend),
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

public struct KamidanaWidget: Decodable, Equatable {
  public let id: String
  public let kind: KamidanaWidgetKind
  public var format: String?
  public var compactFormat: String?
  public var icon: String?
  public var foldedIcon: String?
  public var direction: KamidanaWidgetFolderDirection?
  public var style: KamidanaStyle?
  public var popupStyle: KamidanaStyle?
  public var activate: KamidanaActivation?
  public var motion: KamidanaMotion?
  public var interval: Double?
  public var tooltip: Bool?
  public var tooltipFormat: String?
  public var widgets: [KamidanaWidget]
  public var actionChildren: [KamidanaSystemActionChild]
  public var partStyles: [String: KamidanaStyle]
  public var command: String?
  public var arguments: [String]
  public var inputManagement: Bool?
  public var outputManagement: Bool?
  public var formatOnAction: String?
  public var sliderChange: String?
  public var sliderPause: String?
  public var sliderBar: String?
  public var extend: KamidanaMusicExtendDirection?
  public var artworkSpin: Double?
  public var normal: KamidanaMusicNormalState?
  public var onAction: KamidanaMusicActionState?

  public init(
    id: String,
    kind: KamidanaWidgetKind,
    format: String? = nil,
    compactFormat: String? = nil,
    icon: String? = nil,
    foldedIcon: String? = nil,
    direction: KamidanaWidgetFolderDirection? = nil,
    style: KamidanaStyle? = nil,
    popupStyle: KamidanaStyle? = nil,
    activate: KamidanaActivation? = nil,
    motion: KamidanaMotion? = nil,
    interval: Double? = nil,
    tooltip: Bool? = nil,
    tooltipFormat: String? = nil,
    widgets: [KamidanaWidget] = [],
    actionChildren: [KamidanaSystemActionChild] = [],
    partStyles: [String: KamidanaStyle] = [:],
    command: String? = nil,
    arguments: [String] = [],
    inputManagement: Bool? = nil,
    outputManagement: Bool? = nil,
    formatOnAction: String? = nil,
    sliderChange: String? = nil,
    sliderPause: String? = nil,
    sliderBar: String? = nil,
    extend: KamidanaMusicExtendDirection? = nil,
    artworkSpin: Double? = nil,
    normal: KamidanaMusicNormalState? = nil,
    onAction: KamidanaMusicActionState? = nil
  ) {
    self.id = id
    self.kind = kind
    self.format = format
    self.compactFormat = compactFormat
    self.icon = icon
    self.foldedIcon = foldedIcon
    self.direction = direction
    self.style = style
    self.popupStyle = popupStyle
    self.activate = activate
    self.motion = motion
    self.interval = interval
    self.tooltip = tooltip
    self.tooltipFormat = tooltipFormat
    self.widgets = widgets
    self.actionChildren = actionChildren
    self.partStyles = partStyles
    self.command = command
    self.arguments = arguments
    self.inputManagement = inputManagement
    self.outputManagement = outputManagement
    self.formatOnAction = formatOnAction
    self.sliderChange = sliderChange
    self.sliderPause = sliderPause
    self.sliderBar = sliderBar
    self.extend = extend
    self.artworkSpin = artworkSpin
    self.normal = normal
    self.onAction = onAction
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

    self.init(
      id: id,
      kind: kind,
      format: try container.decodeIfPresent(String.self, forKey: .format),
      compactFormat: try container.decodeIfPresent(String.self, forKey: .compactFormat),
      icon: try container.decodeIfPresent(String.self, forKey: .icon),
      foldedIcon: try container.decodeIfPresent(String.self, forKey: .foldedIcon),
      direction: kind == .widgetFolder ? direction ?? .below : direction,
      style: try container.decodeIfPresent(KamidanaStyle.self, forKey: .style),
      popupStyle: try container.decodeIfPresent(KamidanaStyle.self, forKey: .popupStyle),
      activate: try container.decodeIfPresent(KamidanaActivation.self, forKey: .activate),
      motion: try container.decodeIfPresent(KamidanaMotion.self, forKey: .motion),
      interval: try container.decodeIfPresent(Double.self, forKey: .interval),
      tooltip: try container.decodeIfPresent(Bool.self, forKey: .tooltip),
      tooltipFormat: try container.decodeIfPresent(String.self, forKey: .tooltipFormat),
      widgets: try container.decodeIfPresent([KamidanaWidget].self, forKey: .widgets) ?? [],
      actionChildren: try container.decodeIfPresent(
        [KamidanaSystemActionChild].self, forKey: .children) ?? [],
      partStyles: try container.decodeIfPresent([String: KamidanaStyle].self, forKey: .partStyles)
        ?? [:],
      command: try container.decodeIfPresent(String.self, forKey: .command),
      arguments: try container.decodeIfPresent([String].self, forKey: .arguments) ?? [],
      inputManagement: kind == .volume ? inputManagement ?? true : inputManagement,
      outputManagement: kind == .volume ? outputManagement ?? true : outputManagement,
      formatOnAction: try container.decodeIfPresent(String.self, forKey: .formatOnAction),
      sliderChange: try container.decodeIfPresent(String.self, forKey: .sliderChange),
      sliderPause: try container.decodeIfPresent(String.self, forKey: .sliderPause),
      sliderBar: try container.decodeIfPresent(String.self, forKey: .sliderBar),
      extend: try container.decodeIfPresent(KamidanaMusicExtendDirection.self, forKey: .extend),
      artworkSpin: try container.decodeIfPresent(Double.self, forKey: .artworkSpin),
      normal: try container.decodeIfPresent(KamidanaMusicNormalState.self, forKey: .normal),
      onAction: try container.decodeIfPresent(KamidanaMusicActionState.self, forKey: .onAction)
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
    case activate, motion, interval, tooltip
    case tooltipFormat = "tooltip_format"
    case widgets, children
    case partStyles = "part_styles"
    case command, arguments
    case inputManagement = "input_management"
    case outputManagement = "output_management"
    case formatOnAction = "format_on_action"
    case sliderChange = "slider_change"
    case sliderPause = "slider_pause"
    case sliderBar = "slider_bar"
    case extend
    case artworkSpin = "artwork_spin"
    case normal
    case onAction = "on_action"
  }
}

public struct KamidanaConfigurationV1Global: Decodable, Equatable {
  public var backgroundMode: KamidanaBackgroundMode
  public var hideInFullscreen: Bool
  public var style: KamidanaStyle
  public var popupStyle: KamidanaStyle?

  public init(
    backgroundMode: KamidanaBackgroundMode = .singleBar,
    hideInFullscreen: Bool = false,
    style: KamidanaStyle = KamidanaStyle(),
    popupStyle: KamidanaStyle? = nil
  ) {
    self.backgroundMode = backgroundMode
    self.hideInFullscreen = hideInFullscreen
    self.style = style
    self.popupStyle = popupStyle
  }

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case backgroundMode = "background_mode"
    case hideInFullscreen = "hide_in_fullscreen"
    case style
    case popupStyle = "popup_style"
  }

  public init(from decoder: Decoder) throws {
    try rejectUnknownKeys(in: decoder, knownBy: CodingKeys.self)
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      backgroundMode: try container.decodeIfPresent(
        KamidanaBackgroundMode.self, forKey: .backgroundMode) ?? .singleBar,
      hideInFullscreen: try container.decodeIfPresent(Bool.self, forKey: .hideInFullscreen)
        ?? false,
      style: try container.decodeIfPresent(KamidanaStyle.self, forKey: .style) ?? KamidanaStyle(),
      popupStyle: try container.decodeIfPresent(KamidanaStyle.self, forKey: .popupStyle)
    )
  }
}

public struct KamidanaConfigurationV1Section: Decodable, Equatable {
  public var backgroundMode: KamidanaBackgroundMode?
  public var activate: KamidanaActivation?
  public var style: KamidanaStyle
  public var popupStyle: KamidanaStyle?
  public var widgets: [KamidanaWidget]

  public init(
    backgroundMode: KamidanaBackgroundMode? = nil,
    activate: KamidanaActivation? = nil,
    style: KamidanaStyle = KamidanaStyle(),
    popupStyle: KamidanaStyle? = nil,
    widgets: [KamidanaWidget] = []
  ) {
    self.backgroundMode = backgroundMode
    self.activate = activate
    self.style = style
    self.popupStyle = popupStyle
    self.widgets = widgets
  }

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case backgroundMode = "background_mode"
    case activate, style, widgets
    case popupStyle = "popup_style"
  }

  public init(from decoder: Decoder) throws {
    try rejectUnknownKeys(in: decoder, knownBy: CodingKeys.self)
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      backgroundMode: try container.decodeIfPresent(
        KamidanaBackgroundMode.self, forKey: .backgroundMode),
      activate: try container.decodeIfPresent(KamidanaActivation.self, forKey: .activate),
      style: try container.decodeIfPresent(KamidanaStyle.self, forKey: .style) ?? KamidanaStyle(),
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
      style: try container.decodeIfPresent(KamidanaStyle.self, forKey: .style) ?? KamidanaStyle(),
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
      global: try container.decodeIfPresent(KamidanaConfigurationV1Global.self, forKey: .global)
        ?? KamidanaConfigurationV1Global(),
      left: try container.decodeIfPresent(KamidanaConfigurationV1Section.self, forKey: .left)
        ?? KamidanaConfigurationV1Section(),
      center: try container.decode(KamidanaConfigurationV1Center.self, forKey: .center),
      right: try container.decodeIfPresent(KamidanaConfigurationV1Section.self, forKey: .right)
        ?? KamidanaConfigurationV1Section()
    )
  }

  /// Validates cross-widget rules and typed style ranges after decoding.
  public func validate() throws {
    try validateStyle(global.style, path: "global.style")
    try global.popupStyle.map { try validateStyle($0, path: "global.popup_style") }
    try validateSection(left, name: "left")
    try validateCenter(center)
    try validateSection(right, name: "right")

    var ids = Set<String>()
    try collectIDs(left.widgets, ids: &ids)
    try collectIDs(center.widgets, ids: &ids)
    try collectIDs(right.widgets, ids: &ids)
  }

  private func validateSection(_ section: KamidanaConfigurationV1Section, name: String) throws {
    try validateStyle(section.style, path: "\(name).style")
    try section.popupStyle.map { try validateStyle($0, path: "\(name).popup_style") }
    try validateWidgets(section.widgets, section: name, path: "\(name).widgets", isTopLevel: true)
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
      throw KamidanaConfigurationV1Error.centerDefaultRequiresCompactFormat(section.centerDefault)
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
      if widget.kind == .custom,
        widget.command?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
      {
        throw KamidanaConfigurationV1Error.emptyCustomCommand(widgetPath)
      }
      if widget.kind == .btop && (section != "center" || !isTopLevel) {
        throw KamidanaConfigurationV1Error.btopMustBeInCenter(widget.id)
      }

      try validateKindSpecificFields(widget, path: widgetPath)

      let tooltipFieldsArePresent = widget.tooltip != nil || widget.tooltipFormat != nil
      if tooltipFieldsArePresent && ![.cpu, .gpu, .memory, .network].contains(widget.kind) {
        throw KamidanaConfigurationV1Error.tooltipNotAllowed(widgetPath)
      }
      if widget.tooltip == true,
        widget.tooltipFormat?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
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

  private func validateKindSpecificFields(_ widget: KamidanaWidget, path: String) throws {
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

    if widget.kind != .volume && (widget.inputManagement != nil || widget.outputManagement != nil) {
      throw KamidanaConfigurationV1Error.invalidWidget(
        path: path,
        reason: "input_management and output_management are valid only for volume"
      )
    }

    let hasMusicConfiguration =
      widget.formatOnAction != nil
      || widget.sliderChange != nil
      || widget.sliderPause != nil
      || widget.sliderBar != nil
      || widget.extend != nil
      || widget.artworkSpin != nil
      || widget.normal != nil
      || widget.onAction != nil
    if widget.kind != .music && hasMusicConfiguration {
      throw KamidanaConfigurationV1Error.invalidWidget(
        path: path,
        reason:
          "format_on_action, slider colors, extend, artwork_spin, normal, and on_action are valid only for music"
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
      try validateOptionalFormat(widget.onAction?.format, name: "on_action.format", path: path)
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
    if [.music, .volume, .network, .bluetooth, .widgetFolder, .systemAction].contains(widget.kind) {
      return true
    }
    return widget.activate != nil || widget.tooltip == true
  }

  private func validateActionChildren(_ children: [KamidanaSystemActionChild], path: String) throws
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

/// Contains the complete UI configuration for both display classes in one file.
public struct KamidanaMonitorConfigurationV1: Decodable, Equatable {
  public var external: KamidanaConfigurationV1
  public var builtIn: KamidanaConfigurationV1

  public init(
    external: KamidanaConfigurationV1,
    builtIn: KamidanaConfigurationV1
  ) {
    self.external = external
    self.builtIn = builtIn
  }

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case external
    case builtIn = "built_in"
  }

  public init(from decoder: Decoder) throws {
    try rejectUnknownKeys(in: decoder, knownBy: CodingKeys.self)
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      external: try container.decode(KamidanaConfigurationV1.self, forKey: .external),
      builtIn: try container.decode(KamidanaConfigurationV1.self, forKey: .builtIn)
    )
  }

  public func validate() throws {
    try external.validate()
    try builtIn.validate()
  }
}

/// Yams-backed entry point for monitor-specific configuration strings.
public struct KamidanaMonitorConfigurationV1Decoder {
  public init() {}

  public static func decode(yaml: String) throws -> KamidanaMonitorConfigurationV1 {
    do {
      let configuration = try YAMLDecoder().decode(KamidanaMonitorConfigurationV1.self, from: yaml)
      try configuration.validate()
      return configuration
    } catch let error as KamidanaConfigurationV1Error {
      throw error
    } catch {
      let message = String(describing: error)
      if let marker = message.range(of: "Unsupported widget type '") {
        let remainder = message[marker.upperBound...]
        if let end = remainder.firstIndex(of: "'") {
          throw KamidanaConfigurationV1Error.unsupportedWidgetType(String(remainder[..<end]))
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
      if let marker = message.range(of: "Unsupported widget type '") {
        let remainder = message[marker.upperBound...]
        if let end = remainder.firstIndex(of: "'") {
          throw KamidanaConfigurationV1Error.unsupportedWidgetType(String(remainder[..<end]))
        }
      }
      throw KamidanaConfigurationV1Error.yamlDecoding(String(describing: error))
    }
  }

  public func decode(yaml: String) throws -> KamidanaConfigurationV1 {
    try Self.decode(yaml: yaml)
  }
}
