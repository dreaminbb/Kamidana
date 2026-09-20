import Foundation
import SwiftUI

/// Converts the validated v1 model into the legacy view configuration while the existing
/// widget views are migrated. The adapter is intentionally one-way: legacy YAML is not parsed.
public enum KamidanaConfigurationV1Adapter {
  public static func makeLegacyConfig(from configuration: KamidanaConfigurationV1) -> Config {
    var config = Config()
    let globalStyle = configuration.global.style
    let globalPopupStyle = configuration.global.popupStyle ?? globalStyle
    applyGlobalStyle(globalStyle, to: &config.colors)

    var external = makeLayout(
      globalStyle: globalStyle,
      left: configuration.left.widgets,
      leftStyle: configuration.left.style,
       leftPopupStyle: configuration.left.popupStyle,
       leftActivation: configuration.left.activate,
       leftAnimation: configuration.left.animation,
      center: configuration.center.widgets,
      centerStyle: configuration.center.style,
      centerPopupStyle: configuration.center.popupStyle,
      centerActivation: configuration.center.activate,
      right: configuration.right.widgets,
      rightStyle: configuration.right.style,
       rightPopupStyle: configuration.right.popupStyle,
       rightActivation: configuration.right.activate,
       rightAnimation: configuration.right.animation,
      centerDefault: configuration.center.centerDefault,
      globalPopupStyle: globalPopupStyle,
      colors: config.colors
    )
    external.barPadding = configuration.global.barPadding
    config.externalDisplay = external
    var builtIn = makeLayout(
      globalStyle: globalStyle,
      left: configuration.left.widgets,
      leftStyle: configuration.left.style,
       leftPopupStyle: configuration.left.popupStyle,
       leftActivation: configuration.left.activate,
       leftAnimation: configuration.left.animation,
      center: configuration.center.widgets,
      centerStyle: configuration.center.style,
      centerPopupStyle: configuration.center.popupStyle,
      centerActivation: configuration.center.activate,
      right: configuration.right.widgets,
      rightStyle: configuration.right.style,
       rightPopupStyle: configuration.right.popupStyle,
       rightActivation: configuration.right.activate,
       rightAnimation: configuration.right.animation,
      centerDefault: configuration.center.centerDefault,
      globalPopupStyle: globalPopupStyle,
      colors: config.colors,
      compact: true
    )
    builtIn.barPadding = configuration.global.barPadding
    config.builtInDisplay = builtIn
    return config
  }

  private static func makeLayout(
    globalStyle: KamidanaStyle,
    left: [KamidanaWidget],
    leftStyle: KamidanaStyle,
    leftPopupStyle: KamidanaStyle?,
    leftActivation: KamidanaActivation?,
    leftAnimation: KamidanaMotion?,
    center: [KamidanaWidget],
    centerStyle: KamidanaStyle,
    centerPopupStyle: KamidanaStyle?,
    centerActivation: KamidanaActivation?,
    right: [KamidanaWidget],
    rightStyle: KamidanaStyle,
    rightPopupStyle: KamidanaStyle?,
    rightActivation: KamidanaActivation?,
    rightAnimation: KamidanaMotion?,
    centerDefault: String,
    globalPopupStyle: KamidanaStyle,
    colors: GlobalColorsConfig,
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
          sectionPopupStyle: mergedStyle(globalPopupStyle, leftPopupStyle ?? KamidanaStyle()),
          displayFormat: $0.format,
           activation: $0.activate ?? leftActivation,
           inheritedAnimation: leftAnimation,
          musicPlacement: .standalone,
          defaultMusicExtend: .right,
          colors: colors,
          compact: compact
        )
      },
      center: orderedCenter.compactMap {
        makeWidget(
          $0,
          sectionStyle: mergedStyle(globalStyle, centerStyle),
          sectionPopupStyle: mergedStyle(globalPopupStyle, centerPopupStyle ?? KamidanaStyle()),
          displayFormat: $0.compactFormat ?? $0.normal?.format ?? $0.format,
          activation: $0.activate ?? centerActivation,
          musicPlacement: .center,
          defaultMusicExtend: .right,
          colors: colors,
          compact: compact
        )
      },
      right: right.compactMap {
        makeWidget(
          $0,
          sectionStyle: mergedStyle(globalStyle, rightStyle),
          sectionPopupStyle: mergedStyle(globalPopupStyle, rightPopupStyle ?? KamidanaStyle()),
          displayFormat: $0.format,
           activation: $0.activate ?? rightActivation,
           inheritedAnimation: rightAnimation,
          musicPlacement: .standalone,
          defaultMusicExtend: .left,
          colors: colors,
          compact: compact
        )
      }
    )
  }

  private static func makeWidget(
    _ widget: KamidanaWidget,
    sectionStyle: KamidanaStyle,
    sectionPopupStyle: KamidanaStyle,
    displayFormat: String? = nil,
    activation: KamidanaActivation? = nil,
    inheritedAnimation: KamidanaMotion? = nil,
    musicPlacement: MusicWidgetPlacement = .standalone,
    defaultMusicExtend: KamidanaMusicExtendDirection = .right,
    colors: GlobalColorsConfig,
    compact: Bool
  ) -> WidgetInstance? {
    let style = mergedStyle(sectionStyle, widget.style ?? KamidanaStyle())
    let popupStyle = mergedStyle(sectionPopupStyle, widget.popupStyle ?? KamidanaStyle())
    let animation = inheritedAnimation ?? widget.animation ?? .dynamic
    let resolvedTheme = resolveTheme(style: style, colors: colors, compact: compact)
    let resolvedPopupTheme = resolveTheme(style: popupStyle, colors: colors, isPopup: true, compact: compact)

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
              id: child.id,
              v1Style: childStyle,
              v1PopupStyle: popupStyle,
              v1Format: "\(child.icon) \(child.format)",
              v1Animation: animation,
              theme: resolveTheme(style: childStyle, colors: colors, compact: compact),
              popupTheme: resolvedPopupTheme
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
            ),
            id: widget.id,
            v1Style: style, v1PopupStyle: popupStyle, v1Format: displayFormat,
            v1Activate: activation, v1Animation: animation,
            theme: resolvedTheme, popupTheme: resolvedPopupTheme
          )

        case .widgetFolder:
          let children = widget.widgets.compactMap {
            makeWidget(
              $0,
              sectionStyle: style,
              sectionPopupStyle: popupStyle,
              displayFormat: $0.format,
               activation: $0.activate ?? activation,
               inheritedAnimation: animation,
              musicPlacement: musicPlacement,
              defaultMusicExtend: defaultMusicExtend,
              colors: colors,
              compact: compact
            )
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
            ),
            id: widget.id,
            v1Style: style, v1PopupStyle: popupStyle, v1Format: displayFormat,
             v1Activate: activation, v1Animation: animation,
            theme: resolvedTheme, popupTheme: resolvedPopupTheme
          )

        case .btop:
          guard let path = KamidanaExecutableResolver.resolve("btop") else { return nil }
          return WidgetInstance(
            typeID: "terminal",
            config: TerminalWidgetConfig(
              name: "btop",
              terminalPath: path,
              width: widget.width ?? 700,
              height: widget.height ?? 400
            ),
            id: widget.id,
            v1Style: style, v1PopupStyle: popupStyle, v1Format: displayFormat,
             v1Animation: animation,
            theme: resolvedTheme, popupTheme: resolvedPopupTheme
          )

        case .custom:
          guard let command = widget.command else { return nil }
          return WidgetInstance(
            typeID: "custom",
            config: CustomWidgetConfig(
              command: command,
              arguments: widget.arguments,
              format: displayFormat
            ),
            id: widget.id,
            v1Style: style, v1PopupStyle: popupStyle, v1Format: displayFormat,
             v1Animation: animation,
            theme: resolvedTheme, popupTheme: resolvedPopupTheme
          )

        case .music:
          var value = MusicWidgetConfig()
          if let iconColor = style.iconColor { value.defaultIconColor = iconColor }
          value.normalFormat = widget.normal?.format ?? displayFormat ?? value.normalFormat
          value.formatOnAction =
            widget.normal?.formatOnAction
            ?? widget.formatOnAction
            ?? value.formatOnAction
          value.actionMetadataFormat =
            musicPlacement == .center
            ? widget.onAction?.format ?? value.actionMetadataFormat
            : nil
          value.sliderChangeColor = widget.normal?.sliderChange ?? widget.sliderChange
          value.sliderPauseColor = widget.normal?.sliderPause ?? widget.sliderPause
          value.sliderBarColor = widget.normal?.sliderBar ?? widget.sliderBar
          value.extend = widget.normal?.extend ?? widget.extend ?? defaultMusicExtend
          value.artworkSpinDuration = widget.normal?.artworkSpin ?? widget.artworkSpin ?? 3
          value.actionArtworkSpinDuration =
            widget.onAction?.artworkSpin
            ?? widget.normal?.artworkSpin
            ?? widget.artworkSpin
            ?? 3
          value.placement = musicPlacement
          return WidgetInstance(
            typeID: "music",
            config: value,
            id: widget.id,
            v1Style: style,
            v1PopupStyle: popupStyle,
            v1Format: value.normalFormat,
            v1Activate: activation,
             v1Animation: animation,
            theme: resolvedTheme, popupTheme: resolvedPopupTheme
          )

        case .volume:
          var value = AudioWidgetConfig()
          value.inputManagement = widget.inputManagement
          value.outputManagement = widget.outputManagement
          return WidgetInstance(
            typeID: "audio", config: value,
            id: widget.id,
            v1Style: style, v1PopupStyle: popupStyle,
            v1Format: displayFormat,
             v1Activate: activation, v1Animation: animation,
            theme: resolvedTheme, popupTheme: resolvedPopupTheme)

        case .cpu:
          var value = CpuWidgetConfig()
          if let color = style.color { value.dangerColor = color }
          return WidgetInstance(
            typeID: "cpu", config: value,
            id: widget.id,
            v1Style: style, v1PopupStyle: popupStyle,
            v1Format: displayFormat,
             v1Activate: activation, v1Animation: animation,
            theme: resolvedTheme, popupTheme: resolvedPopupTheme)

        case .gpu:
          return WidgetInstance(
            typeID: "gpu", config: GpuWidgetConfig(),
            id: widget.id,
            v1Style: style,
            v1PopupStyle: popupStyle, v1Format: displayFormat,
             v1Activate: activation, v1Animation: animation,
            theme: resolvedTheme, popupTheme: resolvedPopupTheme)

        case .memory:
          var value = MemoryWidgetConfig()
          if let color = style.iconColor ?? style.color {
            value.iconColor = color
            value.textColor = color
          }
          return WidgetInstance(
            typeID: "memory", config: value,
            id: widget.id,
            v1Style: style, v1PopupStyle: popupStyle,
            v1Format: displayFormat,
             v1Activate: activation, v1Animation: animation,
            theme: resolvedTheme, popupTheme: resolvedPopupTheme)

        case .network:
          var value = NetworkWidgetConfig()
          if let iconColor = style.iconColor { value.iconColor = iconColor }
          if let color = style.color { value.textColor = color }
          return WidgetInstance(
            typeID: "network", config: value,
            id: widget.id,
            v1Style: style, v1PopupStyle: popupStyle,
            v1Format: displayFormat,
             v1Activate: activation, v1Animation: animation,
            theme: resolvedTheme, popupTheme: resolvedPopupTheme)

        case .disk:
          var value = DiskWidgetConfig()
          if let color = style.iconColor ?? style.color {
            value.iconColor = color
            value.textColor = color
          }
          return WidgetInstance(
            typeID: "disk", config: value,
            id: widget.id,
            v1Style: style, v1PopupStyle: popupStyle,
            v1Format: displayFormat,
             v1Activate: activation, v1Animation: animation,
            theme: resolvedTheme, popupTheme: resolvedPopupTheme)

        case .battery:
          var value = BatteryWidgetConfig()
          if let color = style.color { value.dischargingColor = color }
          if let color = style.chargingColor { value.chargingColor = color }
          if let color = style.dischargingColor { value.dischargingColor = color }
          if let color = style.warningColor { value.warningColor = color }
          if let color = style.dangerColor { value.dangerColor = color }
          if let icons = widget.batteryIcons {
            value.charging_right_now = icons.chargingRightNow ?? value.charging_right_now
            value._100_capacity = icons.capacity100 ?? value._100_capacity
            value._90_capacity = icons.capacity90 ?? value._90_capacity
            value._80_capacity = icons.capacity80 ?? value._80_capacity
            value._70_capacity = icons.capacity70 ?? value._70_capacity
            value._60_capacity = icons.capacity60 ?? value._60_capacity
            value._50_capacity = icons.capacity50 ?? value._50_capacity
            value._40_capacity = icons.capacity40 ?? value._40_capacity
            value._30_capacity = icons.capacity30 ?? value._30_capacity
            value._20_capacity = icons.capacity20 ?? value._20_capacity
            value._10_capacity = icons.capacity10 ?? value._10_capacity
            value._sub_10_charged = icons.sub10Charged ?? value._sub_10_charged
          }
          return WidgetInstance(
            typeID: "battery", config: value,
            id: widget.id,
            v1Style: style, v1PopupStyle: popupStyle,
            v1Format: displayFormat,
             v1Activate: activation, v1Animation: animation,
            theme: resolvedTheme, popupTheme: resolvedPopupTheme)

        case .clock:
          var value = ClockWidgetConfig()
          if let color = style.color { value.textColor = color }
          return WidgetInstance(
            typeID: "clock", config: value,
            id: widget.id,
            v1Style: style, v1PopupStyle: popupStyle,
            v1Format: displayFormat,
             v1Activate: activation, v1Animation: animation,
             theme: resolvedTheme, popupTheme: resolvedPopupTheme)

        case .weather:
          return WidgetInstance(
            typeID: "weather",
            config: WeatherWidgetConfig(
              format: displayFormat,
              polling: widget.polling,
              icons: widget.weatherIcons,
              colors: widget.weatherColors
            ),
            id: widget.id,
            v1Style: style, v1PopupStyle: popupStyle,
            v1Format: displayFormat,
            v1Activate: activation, v1Animation: animation,
            theme: resolvedTheme, popupTheme: resolvedPopupTheme)

        case .bluetooth:
          var value = BluetoothWidgetConfig()
          if let color = style.color { value.textColor = color }
          return WidgetInstance(
            typeID: "bluetooth", config: value,
            id: widget.id,
            v1Style: style, v1PopupStyle: popupStyle,
            v1Format: displayFormat,
             v1Activate: activation, v1Animation: animation,
            theme: resolvedTheme, popupTheme: resolvedPopupTheme)
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
      chargingColor: child.chargingColor ?? parent.chargingColor,
      dischargingColor: child.dischargingColor ?? parent.dischargingColor,
      warningColor: child.warningColor ?? parent.warningColor,
      dangerColor: child.dangerColor ?? parent.dangerColor,
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

  public static func resolveTheme(
    style: KamidanaStyle,
    colors: GlobalColorsConfig,
    isPopup: Bool = false,
    compact: Bool = false
  ) -> Theme {
    let backgroundHex = style.background ?? (isPopup ? colors.background : colors.surface)
    let foregroundHex = style.color ?? colors.textPrimary
    let iconHex = style.iconColor ?? foregroundHex

    let defaultHorizontalPadding: Double = compact ? 8 : 12
    let defaultPadding = KamidanaInsets(
      top: 6, bottom: 9, leading: defaultHorizontalPadding, trailing: defaultHorizontalPadding
    )

    let padding = style.padding ?? (isPopup ? KamidanaInsets(top: 12, bottom: 12, leading: 12, trailing: 12) : defaultPadding)
    let cornerRadius = style.cornerRadius ?? (isPopup ? 12 : (compact ? 8 : 12))

    let borderWidth = style.border?.width ?? (isPopup ? 1 : 0)
    let borderColor = style.border?.color ?? colors.surfaceBorder

    var hoverTheme: Theme.HoverTheme? = nil
    if let hoverStyle = style.states["hover"] {
        hoverTheme = Theme.HoverTheme(
            background: hoverStyle.background.map(Color.init(hex:)),
            foreground: hoverStyle.color.map(Color.init(hex:)),
            iconForeground: hoverStyle.iconColor.map(Color.init(hex:)),
            border: hoverStyle.border,
            shadow: hoverStyle.shadow,
            opacity: hoverStyle.opacity
        )
    } else if !isPopup {
        // Default hover behavior for normal widgets
        hoverTheme = Theme.HoverTheme(
            background: Color(hex: colors.surfaceHighlight),
            foreground: nil,
            iconForeground: nil,
            border: KamidanaBorder(width: borderWidth, color: colors.surfaceBorder),
            shadow: nil
        )
    }

    let pressedTheme = style.states["pressed"].map { pressedStyle in
      Theme.PressedTheme(
        background: pressedStyle.background.map(Color.init(hex:)),
        foreground: pressedStyle.color.map(Color.init(hex:)),
        iconForeground: pressedStyle.iconColor.map(Color.init(hex:)),
        border: pressedStyle.border,
        shadow: pressedStyle.shadow,
        opacity: pressedStyle.opacity
      )
    }

    let standardMotion = Theme.Motion.standard
    let motionAnimation = style.animation
    let motion = Theme.Motion(
      hover: style.states["hover"]?.animation ?? motionAnimation ?? standardMotion.hover,
      expand: motionAnimation ?? standardMotion.expand,
      colorChange: style.states["warning"]?.animation ?? motionAnimation
        ?? standardMotion.colorChange,
      hoverSettleDelay: standardMotion.hoverSettleDelay,
      popupDismissDelay: standardMotion.popupDismissDelay
    )
    let severityColors = Theme.SeverityColors(
      normal: Color(hex: foregroundHex),
      warning: Color(hex: style.states["warning"]?.color ?? colors.warning),
      critical: Color(hex: style.states["critical"]?.color ?? colors.danger)
    )

    return Theme(
        background: Color(hex: backgroundHex).opacity(style.opacity ?? (isPopup ? 0.96 : 0.6)),
        foreground: Color(hex: foregroundHex),
        iconForeground: Color(hex: iconHex),
        padding: padding,
        spacing: CGFloat(style.spacing ?? 8),
        cornerRadius: CGFloat(cornerRadius),
        border: KamidanaBorder(width: borderWidth, color: borderColor),
        shadow: style.shadow,
        material: style.material ?? .ultraThin,
        animation: style.animation,
        hoverTheme: hoverTheme,
        pressedTheme: pressedTheme,
        motion: motion,
        severityColors: severityColors
    )
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
