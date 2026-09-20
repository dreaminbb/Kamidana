import AppKit
import SwiftUI

enum WidgetSurfaceMetrics {
  static let additionalWidth: CGFloat = 10
  static let additionalHorizontalPadding = additionalWidth / 2
}

struct IsInsideWidgetFolderKey: EnvironmentKey {
  static let defaultValue: Bool = false
}

extension EnvironmentValues {
  var isInsideWidgetFolder: Bool {
    get { self[IsInsideWidgetFolderKey.self] }
    set { self[IsInsideWidgetFolderKey.self] = newValue }
  }
}

struct SmoothUIModuleModifier: ViewModifier {
  let isPressed: Bool

  func body(content: Content) -> some View {
    content.modifier(WidgetInteractionModifier(isPressed: isPressed))
  }
}

private struct WidgetInteractionAppearance {
  var background: Color?
  var foreground: Color?
  var border: KamidanaBorder?
  var shadow: KamidanaShadow?
  var opacity: Double
  var scale: CGFloat
}

private struct WidgetInteractionModifier: ViewModifier {
  @Environment(\.theme) private var theme: Theme?
  @Environment(\.widgetSeverity) private var severity
  @Environment(\.kamidanaWidgetActivation) private var widgetActivation
  @Environment(\.showsKamidanaWidgetSurface) private var showsWidgetSurface
  @Environment(\.isInsideWidgetFolder) private var isInsideWidgetFolder
  @State private var interactionState = WidgetInteractionState.idle
  @State private var hoverTracker = WidgetHoverTracker()

  let isPressed: Bool

  private var resolvedState: WidgetInteractionState {
    if isPressed { return .pressed }
    return widgetActivation == .click ? .idle : interactionState
  }

  func body(content: Content) -> some View {
    let appearance = appearance(for: resolvedState)
    let severityColor = severity == .normal
      ? nil
      : theme?.severityColors.color(for: severity)
    let foreground = severityColor ?? appearance.foreground ?? theme?.foreground ?? .primary
    let baseCornerRadius = theme?.cornerRadius ?? 0
    let motion = theme?.motion ?? .standard
    let stateAnimation = motion.animation(for: resolvedState).resolvedAnimation()
    let colorAnimation = motion.colorChange.resolvedAnimation()
    let styledContent = content
      .foregroundColor(foreground)
      .opacity(appearance.opacity)

    guard !isInsideWidgetFolder, showsWidgetSurface else {
      return AnyView(styledContent)
    }

    let leadingPadding = (theme?.padding.leading ?? 0) + WidgetSurfaceMetrics.additionalHorizontalPadding
    let trailingPadding = (theme?.padding.trailing ?? 0) + WidgetSurfaceMetrics.additionalHorizontalPadding
    let topPadding = theme?.padding.top ?? 0
    let bottomPadding = theme?.padding.bottom ?? 0
    let background = appearance.background ?? theme?.background ?? .clear
    let border = appearance.border ?? theme?.border ?? KamidanaBorder(width: 0, color: nil)
    let borderColor = border.color.map(Color.init(hex:)) ?? .clear
    let material = materialStyle(for: theme?.material)
    let shadow = appearance.shadow ?? theme?.shadow
    let hitShape = RoundedRectangle(cornerRadius: baseCornerRadius)

    let visualContent = styledContent
      .padding(.leading, leadingPadding)
      .padding(.trailing, trailingPadding)
      .padding(.top, topPadding)
      .padding(.bottom, bottomPadding)
      .background(background)
      .background(material)
      .cornerRadius(baseCornerRadius)
      .overlay(
        RoundedRectangle(cornerRadius: baseCornerRadius)
          .stroke(borderColor, lineWidth: border.width)
      )
      .scaleEffect(appearance.scale)
      .shadow(
        color: shadow?.color.map(Color.init(hex:)) ?? .clear,
        radius: shadow?.radius ?? 0,
        x: shadow?.x ?? 0,
        y: shadow?.y ?? 0
      )

    return AnyView(
      visualContent
        // Keep the interaction layer out of layout measurement. A sibling
        // Color.clear in a ZStack can consume the HStack proposal in per-widget mode.
        .overlay {
          Color.clear
            .contentShape(.interaction, hitShape)
            .onHover { hovering in
              guard widgetActivation != .click else {
                hoverTracker.reset()
                return
              }
              hoverTracker.update(
                hovering,
                delay: motion.hoverSettleDelay
              ) { interactionState = $0 ? .hover : .idle }
            }
        }
      .animation(stateAnimation, value: resolvedState)
      .animation(colorAnimation, value: severity)
    )
  }

  private func appearance(for state: WidgetInteractionState) -> WidgetInteractionAppearance {
    switch state {
    case .idle:
      return WidgetInteractionAppearance(
        background: theme?.background,
        foreground: theme?.foreground,
        border: theme?.border,
        shadow: theme?.shadow,
        opacity: 1,
        scale: 1
      )
    case .hover:
      return WidgetInteractionAppearance(
        background: theme?.hoverTheme?.background,
        foreground: theme?.hoverTheme?.foreground,
        border: theme?.hoverTheme?.border,
        shadow: theme?.hoverTheme?.shadow,
        opacity: theme?.hoverTheme?.opacity ?? 1,
        scale: theme?.hoverTheme?.scale ?? 1
      )
    case .pressed:
      return WidgetInteractionAppearance(
        background: theme?.pressedTheme?.background,
        foreground: theme?.pressedTheme?.foreground,
        border: theme?.pressedTheme?.border,
        shadow: theme?.pressedTheme?.shadow,
        opacity: theme?.pressedTheme?.opacity ?? 1,
        scale: theme?.pressedTheme?.scale ?? 1
      )
    }
  }

  private func materialStyle(for material: KamidanaMaterial?) -> AnyShapeStyle {
    switch material {
    case .some(.none): return AnyShapeStyle(Color.clear)
    case .thin: return AnyShapeStyle(.thinMaterial)
    case .regular: return AnyShapeStyle(.regularMaterial)
    case .thick: return AnyShapeStyle(.thickMaterial)
    case .chrome: return AnyShapeStyle(.bar)
    case .some(.ultraThin), nil: return AnyShapeStyle(.ultraThinMaterial)
    }
  }
}

struct KamidanaSectionSurfaceModifier: ViewModifier {
  let style: KamidanaStyle?
  let isEnabled: Bool
  let includesPadding: Bool
  let outerPadding: KamidanaInsets?
  let appliesOuterPaddingToContent: Bool
  let hideBorderWhenOuterPaddingIsZero: Bool

  func body(content: Content) -> some View {
    let colors = ConfigManager.shared.currentConfig.colors
    let padding = style?.padding
    let cornerRadius = style?.cornerRadius ?? 12
    let background = style?.background ?? colors.background
    let opacity = style?.opacity ?? 0.6
    let borderColor = style?.border?.color ?? colors.surface
    let outerTop = outerPadding?.top ?? 0
    let outerBottom = outerPadding?.bottom ?? 0
    let outerLeading = outerPadding?.leading ?? 0
    let outerTrailing = outerPadding?.trailing ?? 0
    let borderWidth = style?.border?.width ?? 1
    let material: AnyShapeStyle = {
      switch style?.material {
      case .some(.none): return AnyShapeStyle(Color.clear)
      case .thin: return AnyShapeStyle(.thinMaterial)
      case .regular: return AnyShapeStyle(.regularMaterial)
      case .thick: return AnyShapeStyle(.thickMaterial)
      case .chrome: return AnyShapeStyle(.bar)
      case .some(.ultraThin), nil: return AnyShapeStyle(.ultraThinMaterial)
      }
    }()

    if !isEnabled {
      return AnyView(content)
    }

    return AnyView(
      content
        .padding(.top, appliesOuterPaddingToContent ? outerTop : 0)
        .padding(.bottom, appliesOuterPaddingToContent ? outerBottom : 0)
        .padding(.leading, appliesOuterPaddingToContent ? outerLeading : 0)
        .padding(.trailing, appliesOuterPaddingToContent ? outerTrailing : 0)
        .padding(.top, includesPadding ? padding?.top ?? 0 : 0)
        .padding(.bottom, includesPadding ? padding?.bottom ?? 0 : 0)
        .padding(.leading, includesPadding ? padding?.leading ?? 0 : 0)
        .padding(.trailing, includesPadding ? padding?.trailing ?? 0 : 0)
        // Keep the section surface rounded without clipping child overlays such as
        // the vertical WidgetFolder expansion.
        .background(
          RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(hex: background).opacity(opacity))
        )
        .background(
          RoundedRectangle(cornerRadius: cornerRadius)
            .fill(material)
        )
        .overlay {
          if borderWidth > 0 {
            GeometryReader { proxy in
              let size = proxy.size
              let topVisible = !hideBorderWhenOuterPaddingIsZero || outerTop > 0
              let sideVisible = !hideBorderWhenOuterPaddingIsZero || outerTrailing > 0
              let bottomVisible = true
              let leadingVisible = sideVisible
              let trailingVisible = sideVisible
              let inset = borderWidth / 2
              let horizontalInset = max(cornerRadius, inset)
              let verticalInset = max(cornerRadius, inset)

              Path { path in
                if topVisible {
                  path.move(to: CGPoint(x: horizontalInset, y: inset))
                  path.addLine(
                    to: CGPoint(x: size.width - horizontalInset, y: inset))
                }
                if bottomVisible {
                  path.move(to: CGPoint(x: horizontalInset, y: size.height - inset))
                  path.addLine(
                    to: CGPoint(x: size.width - horizontalInset, y: size.height - inset))
                }
                if leadingVisible {
                  path.move(to: CGPoint(x: inset, y: verticalInset))
                  path.addLine(
                    to: CGPoint(x: inset, y: size.height - verticalInset))
                }
                if trailingVisible {
                  path.move(to: CGPoint(x: size.width - inset, y: verticalInset))
                  path.addLine(
                    to: CGPoint(x: size.width - inset, y: size.height - verticalInset))
                }
              }
              .stroke(Color(hex: borderColor), lineWidth: borderWidth)
              .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
          }
        }
        .shadow(
          color: Color(hex: style?.shadow?.color ?? colors.background)
            .opacity(style?.shadow?.opacity ?? 0),
          radius: style?.shadow?.radius ?? 0,
          x: style?.shadow?.x ?? 0,
          y: style?.shadow?.y ?? 0
        )
    )
  }
}

struct KamidanaPopupSurfaceModifier: ViewModifier {
  @Environment(\.popupTheme) private var popupTheme: Theme?

  func body(content: Content) -> some View {
    let cornerRadius = popupTheme?.cornerRadius ?? 12
    let background = popupTheme?.background ?? .clear
    let foreground = popupTheme?.foreground ?? .primary
    let borderColor = popupTheme?.border.color.map(Color.init(hex:)) ?? .clear
    let borderWidth = popupTheme?.border.width ?? 1
    let material: AnyShapeStyle = {
      switch popupTheme?.material {
      case .some(.none): return AnyShapeStyle(Color.clear)
      case .thin: return AnyShapeStyle(.thinMaterial)
      case .regular: return AnyShapeStyle(.regularMaterial)
      case .thick: return AnyShapeStyle(.thickMaterial)
      case .chrome: return AnyShapeStyle(.bar)
      case .some(.ultraThin), nil: return AnyShapeStyle(.ultraThinMaterial)
      }
    }()

    content
      .foregroundColor(foreground)
      .background(background)
      .background(material)
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius)
          .stroke(borderColor, lineWidth: borderWidth)
      )
      .shadow(
        color: popupTheme?.shadow?.color.map(Color.init(hex:)) ?? .clear,
        radius: popupTheme?.shadow?.radius ?? 12,
        x: popupTheme?.shadow?.x ?? 0,
        y: popupTheme?.shadow?.y ?? 6
      )
      .contentShape(.interaction, RoundedRectangle(cornerRadius: cornerRadius))
  }
}

struct WidgetButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .modifier(SmoothUIModuleModifier(isPressed: configuration.isPressed))
  }
}

extension View {
  func SmoothUIModule() -> some View {
    self.modifier(SmoothUIModuleModifier(isPressed: false))
  }

  func SmoothUIModule(theme: Theme?) -> some View {
    self.environment(\.theme, theme)
      .modifier(SmoothUIModuleModifier(isPressed: false))
  }

  func kamidanaSectionSurface(
    style: KamidanaStyle?,
    isEnabled: Bool,
    includesPadding: Bool = true,
    outerPadding: KamidanaInsets? = nil,
    appliesOuterPaddingToContent: Bool = true,
    hideBorderWhenOuterPaddingIsZero: Bool = false
  ) -> some View {
    modifier(
      KamidanaSectionSurfaceModifier(
        style: style,
        isEnabled: isEnabled,
        includesPadding: includesPadding,
        outerPadding: outerPadding,
        appliesOuterPaddingToContent: appliesOuterPaddingToContent,
        hideBorderWhenOuterPaddingIsZero: hideBorderWhenOuterPaddingIsZero
      ))
  }
}
