import Foundation

/// Converts the validated v1 model into the legacy view configuration while the existing
/// widget views are migrated. The adapter is intentionally one-way: legacy YAML is not parsed.
public enum KamidanaConfigurationV1Adapter {
  public static func makeLegacyConfig(from configuration: KamidanaConfigurationV1) -> Config {
    var config = Config()
    let globalStyle = configuration.global.style
    applyGlobalStyle(globalStyle, to: &config.colors)

    let external = makeLayout(
      globalStyle: globalStyle,
      left: configuration.left.widgets,
      leftStyle: configuration.left.style,
      center: configuration.center.widgets,
      centerStyle: configuration.center.style,
      right: configuration.right.widgets,
      rightStyle: configuration.right.style,
      centerDefault: configuration.center.centerDefault
    )
    config.externalDisplay = external
    config.builtInDisplay = makeLayout(
      globalStyle: globalStyle,
      left: configuration.left.widgets,
      leftStyle: configuration.left.style,
      center: configuration.center.widgets,
      centerStyle: configuration.center.style,
      right: configuration.right.widgets,
      rightStyle: configuration.right.style,
      centerDefault: configuration.center.centerDefault,
      compact: true
    )
    return config
  }

  private static func makeLayout(
    globalStyle: KamidanaStyle,
    left: [KamidanaWidget],
    leftStyle: KamidanaStyle,
    center: [KamidanaWidget],
    centerStyle: KamidanaStyle,
    right: [KamidanaWidget],
    rightStyle: KamidanaStyle,
    centerDefault: String,
    compact: Bool = false
  ) -> DisplayLayoutConfig {
    let layoutStyle = legacyStyle(globalStyle, compact: compact)
    var orderedCenter = center
    if let defaultIndex = orderedCenter.firstIndex(where: { $0.id == centerDefault }) {
      let defaultWidget = orderedCenter.remove(at: defaultIndex)
      orderedCenter.insert(defaultWidget, at: 0)
    }
    return DisplayLayoutConfig(
      style: layoutStyle,
      left: left.compactMap {
        makeWidget(
          $0,
          sectionStyle: mergedStyle(globalStyle, leftStyle),
          displayFormat: $0.format
        )
      },
      center: orderedCenter.compactMap {
        makeWidget(
          $0,
          sectionStyle: mergedStyle(globalStyle, centerStyle),
          displayFormat: $0.compactFormat ?? $0.format
        )
      },
      right: right.compactMap {
        makeWidget(
          $0,
          sectionStyle: mergedStyle(globalStyle, rightStyle),
          displayFormat: $0.format
        )
      }
    )
  }

  private static func makeWidget(
    _ widget: KamidanaWidget,
    sectionStyle: KamidanaStyle,
    displayFormat: String? = nil
  ) -> WidgetInstance? {
    let style = mergedStyle(sectionStyle, widget.style ?? KamidanaStyle())
    switch widget.kind {
    case .systemAction:
      let children = widget.actionChildren.map { child in
        let childStyle = mergedStyle(style, child.style)
        return WidgetInstance(
          typeID: "systemAction",
          config: SystemActionWidgetConfig(
            action: legacyActionName(child.action),
            name: child.format,
            icon: child.icon,
            iconColor: childStyle.iconColor ?? "#cba6f7"
          ),
          v1Style: childStyle,
          v1Format: "\(child.icon) \(child.format)"
        )
      }
      return WidgetInstance(
        typeID: "widgetFolder",
        config: WidgetFolderConfig(
          name: nil,
          icon: widget.icon,
          iconFolded: widget.foldedIcon,
          iconColor: style.iconColor ?? "#cba6f7",
          direction: "below",
          widgets: children
        ), v1Style: style, v1Format: displayFormat
      )

    case .widgetFolder:
      let children = widget.widgets.compactMap {
        makeWidget($0, sectionStyle: style, displayFormat: $0.format)
      }
      return WidgetInstance(
        typeID: "widgetFolder",
        config: WidgetFolderConfig(
          name: nil,
          icon: widget.icon,
          iconFolded: widget.foldedIcon,
          iconColor: style.iconColor ?? "#cba6f7",
          direction: widget.direction?.rawValue ?? "below",
          widgets: children
        ), v1Style: style, v1Format: displayFormat
      )

    case .btop:
      guard let path = KamidanaExecutableResolver.resolve("btop") else { return nil }
      return WidgetInstance(
        typeID: "terminal",
        config: TerminalWidgetConfig(
          name: "btop",
          terminalPath: path
        ), v1Style: style, v1Format: displayFormat
      )

    case .custom:
      guard let command = widget.command else { return nil }
      return WidgetInstance(
        typeID: "custom",
        config: CustomWidgetConfig(
          command: command,
          arguments: widget.arguments,
          format: displayFormat
        ), v1Style: style, v1Format: displayFormat
      )

    case .music:
      var value = MusicWidgetConfig()
      if let iconColor = style.iconColor { value.defaultIconColor = iconColor }
      return WidgetInstance(
        typeID: "music", config: value, v1Style: style, v1Format: displayFormat)

    case .volume:
      return WidgetInstance(
        typeID: "audio", config: AudioWidgetConfig(), v1Style: style, v1Format: displayFormat)

    case .cpu:
      var value = CpuWidgetConfig()
      if let color = style.color { value.dangerColor = color }
      return WidgetInstance(
        typeID: "cpu", config: value, v1Style: style, v1Format: displayFormat)

    case .gpu:
      return WidgetInstance(
        typeID: "gpu", config: GpuWidgetConfig(), v1Style: style, v1Format: displayFormat)

    case .memory:
      var value = MemoryWidgetConfig()
      if let color = style.iconColor ?? style.color {
        value.iconColor = color
        value.textColor = color
      }
      return WidgetInstance(
        typeID: "memory", config: value, v1Style: style, v1Format: displayFormat)

    case .network:
      var value = NetworkWidgetConfig()
      if let iconColor = style.iconColor { value.iconColor = iconColor }
      if let color = style.color { value.textColor = color }
      return WidgetInstance(
        typeID: "network", config: value, v1Style: style, v1Format: displayFormat)

    case .disk:
      var value = DiskWidgetConfig()
      if let color = style.iconColor ?? style.color {
        value.iconColor = color
        value.textColor = color
      }
      return WidgetInstance(
        typeID: "disk", config: value, v1Style: style, v1Format: displayFormat)

    case .battery:
      var value = BatteryWidgetConfig()
      if let color = style.color { value.dischargingColor = color }
      return WidgetInstance(
        typeID: "battery", config: value, v1Style: style, v1Format: displayFormat)

    case .clock:
      var value = ClockWidgetConfig()
      if let color = style.color { value.textColor = color }
      return WidgetInstance(
        typeID: "clock", config: value, v1Style: style, v1Format: displayFormat)

    case .wifi:
      var value = WifiWidgetConfig()
      if let color = style.iconColor { value.iconColor = color }
      if let color = style.color { value.textColor = color }
      return WidgetInstance(
        typeID: "wifi", config: value, v1Style: style, v1Format: displayFormat)

    case .bluetooth:
      var value = BluetoothWidgetConfig()
      if let color = style.color { value.textColor = color }
      return WidgetInstance(
        typeID: "bluetooth", config: value, v1Style: style, v1Format: displayFormat)
    }
  }

  private static func legacyActionName(_ action: KamidanaSystemAction) -> String {
    switch action {
    case .aboutThisMac: return "aboutThisMac"
    case .lockScreen: return "lockScreen"
    default: return action.rawValue
    }
  }

  public static func mergedStyle(
    _ parent: KamidanaStyle,
    _ child: KamidanaStyle
  ) -> KamidanaStyle {
    KamidanaStyle(
      background: child.background ?? parent.background,
      color: child.color ?? parent.color,
      iconColor: child.iconColor ?? parent.iconColor,
      opacity: child.opacity ?? parent.opacity,
      padding: child.padding ?? parent.padding,
      spacing: child.spacing ?? parent.spacing,
      cornerRadius: child.cornerRadius ?? parent.cornerRadius,
      border: child.border ?? parent.border,
      shadow: child.shadow ?? parent.shadow,
      material: child.material ?? parent.material,
      animation: child.animation ?? parent.animation,
      states: parent.states.merging(child.states) { _, child in child }
    )
  }

  public static func style(
    _ style: KamidanaStyle,
    applyingState state: String
  ) -> KamidanaStyle {
    guard let override = style.states[state] else { return style }
    return mergedStyle(style, override)
  }

  private static func legacyStyle(_ style: KamidanaStyle, compact: Bool) -> WidgetStyleConfig {
    let padding = style.padding
    let horizontal =
      padding.map { ($0.leading + $0.trailing) / 2 }
      ?? (compact ? 8 : 12)
    return WidgetStyleConfig(
      paddingHorizontal: horizontal,
      paddingTop: padding?.top ?? 6,
      paddingBottom: padding?.bottom ?? 9,
      cornerRadius: style.cornerRadius ?? (compact ? 8 : 12),
      backgroundColorOpacity: style.opacity ?? 0.6,
      hoverBackgroundColorOpacity: style.opacity.map { min(1, $0 + 0.2) } ?? 0.8
    )
  }

  private static func applyGlobalStyle(_ style: KamidanaStyle, to colors: inout GlobalColorsConfig)
  {
    if let background = style.background { colors.background = background }
    if let color = style.color { colors.textPrimary = color }
  }
}

public enum KamidanaExecutableResolver {
  public static func resolve(
    _ name: String, environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> String? {
    if name.contains("/") && FileManager.default.isExecutableFile(atPath: name) { return name }
    guard let path = environment["PATH"] else { return nil }
    return path.split(separator: ":").map(String.init)
      .map { URL(fileURLWithPath: $0).appendingPathComponent(name).path }
      .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
  }
}
