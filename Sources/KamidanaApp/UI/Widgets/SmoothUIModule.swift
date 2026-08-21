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
  @Environment(\.widgetStyle) var style: WidgetStyleConfig
  @Environment(\.kamidanaV1Style) var v1Style: KamidanaStyle?
  @Environment(\.showsKamidanaWidgetSurface) var showsWidgetSurface: Bool
  @Environment(\.isInsideWidgetFolder) var isInsideWidgetFolder: Bool
  @State private var isHovered = false

  func body(content: Content) -> some View {
    let colors = ConfigManager.shared.currentConfig.colors
    let effectiveStyle = v1Style.map {
      isHovered
        ? KamidanaConfigurationV1Adapter.style($0, applyingState: "hover")
        : $0
    }
    let padding = effectiveStyle?.padding
    let leadingPadding =
      (padding?.leading ?? style.paddingHorizontal)
      + WidgetSurfaceMetrics.additionalHorizontalPadding
    let trailingPadding =
      (padding?.trailing ?? style.paddingHorizontal)
      + WidgetSurfaceMetrics.additionalHorizontalPadding
    let topPadding = padding?.top ?? style.paddingTop
    let bottomPadding = padding?.bottom ?? style.paddingBottom
    let cornerRadius = effectiveStyle?.cornerRadius ?? style.cornerRadius
    let background =
      effectiveStyle?.background
      ?? (isHovered ? colors.surfaceHighlight : colors.background)
    let foreground = effectiveStyle?.color
    let opacity =
      effectiveStyle?.opacity
      ?? (isHovered ? style.hoverBackgroundColorOpacity : style.backgroundColorOpacity)
    let borderColor =
      effectiveStyle?.border?.color
      ?? (isHovered ? colors.surfaceBorder : colors.surface)
    let borderWidth = effectiveStyle?.border?.width ?? 1
    let material: AnyShapeStyle = {
      switch effectiveStyle?.material {
      case .some(.none): return AnyShapeStyle(Color.clear)
      case .thin: return AnyShapeStyle(.thinMaterial)
      case .regular: return AnyShapeStyle(.regularMaterial)
      case .thick: return AnyShapeStyle(.thickMaterial)
      case .chrome: return AnyShapeStyle(.bar)
      case .some(.ultraThin): return AnyShapeStyle(.ultraThinMaterial)
      case nil: return AnyShapeStyle(.ultraThinMaterial)
      }
    }()
    let transition: Animation? = {
      switch effectiveStyle?.animation?.preset {
      case .linear: return .linear(duration: effectiveStyle?.animation?.durationSeconds ?? 0.2)
      case .easeInOut:
        return .easeInOut(duration: effectiveStyle?.animation?.durationSeconds ?? 0.2)
      case .spring:
        return .spring(
          response: effectiveStyle?.animation?.response ?? 0.5,
          dampingFraction: effectiveStyle?.animation?.damping ?? 0.7,
          blendDuration: effectiveStyle?.animation?.blendDuration ?? 0
        )
      case .some(.none): return nil
      case nil: return .easeInOut(duration: 0.2)
      }
    }()
    let styledContent =
      content
      .foregroundColor(foreground.map(Color.init(hex:)) ?? Color(hex: colors.textPrimary))

    if isInsideWidgetFolder || !showsWidgetSurface {
      return AnyView(styledContent)
    }

    return AnyView(
      styledContent
        .padding(.leading, leadingPadding)
        .padding(.trailing, trailingPadding)
        // Keep top at 6px and thicken bottom by 3px (total 9px)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        // On hover use surfaceHighlight, normally use semi-transparent background
        .background(Color(hex: background).opacity(opacity))
        // Layer UltraThinMaterial for a glass-like blur effect
        .background(material)
        .cornerRadius(cornerRadius)
        .overlay(
          RoundedRectangle(cornerRadius: cornerRadius)
            // Highlight border subtly on hover
            .stroke(Color(hex: borderColor), lineWidth: borderWidth)
        )
        // Hover animation
        .animation(transition, value: isHovered)
        .shadow(
          color: Color(hex: effectiveStyle?.shadow?.color ?? colors.background)
            .opacity(effectiveStyle?.shadow?.opacity ?? 0),
          radius: effectiveStyle?.shadow?.radius ?? 0,
          x: effectiveStyle?.shadow?.x ?? 0,
          y: effectiveStyle?.shadow?.y ?? 0
        )
        .onHover { hovering in
          isHovered = hovering
        })
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
  @Environment(\.kamidanaPopupStyle) private var style

  func body(content: Content) -> some View {
    let colors = ConfigManager.shared.currentConfig.colors
    let cornerRadius = style?.cornerRadius ?? 12
    let background = style?.background ?? colors.background
    let opacity = style?.opacity ?? 0.96
    let borderColor = style?.border?.color ?? colors.surfaceBorder
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

    content
      .foregroundColor(style?.color.map(Color.init(hex:)) ?? Color(hex: colors.textPrimary))
      .background(
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(Color(hex: background).opacity(opacity))
      )
      .background(
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(material)
      )
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius)
          .stroke(Color(hex: borderColor), lineWidth: borderWidth)
      )
      .shadow(
        color: Color(hex: style?.shadow?.color ?? colors.background)
          .opacity(style?.shadow?.opacity ?? 0.28),
        radius: style?.shadow?.radius ?? 12,
        x: style?.shadow?.x ?? 0,
        y: style?.shadow?.y ?? 6
      )
      .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
  }
}

private struct WidgetPopupModifier<PopupContent: View>: ViewModifier {
  @Binding var isPresented: Bool
  let activation: KamidanaActivation
  let hoverState: WidgetPopoverHoverState
  let popupContent: () -> PopupContent

  @Environment(\.kamidanaWidgetMotion) private var motion
  @Environment(\.kamidanaPopupHorizontalAlignment) private var horizontalAlignment

  func body(content: Content) -> some View {
    content
      .zIndex(isPresented ? 1_000 : 0)
      .overlay(alignment: horizontalAlignment.swiftUIAlignment) {
        if isPresented {
          popupContent()
            .modifier(KamidanaPopupSurfaceModifier())
            .offset(y: 40)
            .transition(popupTransition)
            .onHover {
              hoverState.updatePopoverHover(
                $0,
                isPresented: $isPresented,
                activation: activation
              )
            }
            .zIndex(1_000)
        }
      }
      .animation(popupAnimation, value: isPresented)
      .onReceive(
        NSWorkspace.shared.notificationCenter.publisher(
          for: NSWorkspace.didActivateApplicationNotification
        )
      ) { notification in
        guard
          let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication,
          application.bundleIdentifier != Bundle.main.bundleIdentifier
        else { return }
        hoverState.reset()
        isPresented = false
      }
  }

  private var popupAnimation: Animation? {
    guard motion == .dynamic else { return nil }
    return .spring(response: 0.3, dampingFraction: 0.84)
  }

  private var popupTransition: AnyTransition {
    guard motion == .dynamic else { return .identity }
    return .move(edge: .top).combined(with: .opacity)
  }
}

struct WidgetButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .SmoothUIModule()
      .contentShape(Rectangle())
      .opacity(configuration.isPressed ? 0.88 : 1)
  }
}

final class WidgetPopoverHoverState {
  private var isAnchorHovered = false
  private var isPopoverHovered = false
  private var pendingCloseID: UUID?

  static func shouldRemainPresented(anchorHovered: Bool, popoverHovered: Bool) -> Bool {
    anchorHovered || popoverHovered
  }

  func updateAnchorHover(
    _ isHovered: Bool,
    isPresented: Binding<Bool>,
    activation: KamidanaActivation
  ) {
    guard activation == .hover else { return }
    isAnchorHovered = isHovered
    updatePresentation(isPresented: isPresented)
  }

  func updatePopoverHover(
    _ isHovered: Bool,
    isPresented: Binding<Bool>,
    activation: KamidanaActivation
  ) {
    guard activation == .hover else { return }
    isPopoverHovered = isHovered
    updatePresentation(isPresented: isPresented)
  }

  func reset() {
    isAnchorHovered = false
    isPopoverHovered = false
    pendingCloseID = nil
  }

  private func updatePresentation(isPresented: Binding<Bool>) {
    guard !Self.shouldRemainPresented(
      anchorHovered: isAnchorHovered,
      popoverHovered: isPopoverHovered
    ) else {
      pendingCloseID = nil
      isPresented.wrappedValue = true
      return
    }

    let closeID = UUID()
    pendingCloseID = closeID
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
      guard self?.pendingCloseID == closeID,
            let self,
            !Self.shouldRemainPresented(
              anchorHovered: self.isAnchorHovered,
              popoverHovered: self.isPopoverHovered
            ) else { return }
      isPresented.wrappedValue = false
    }
  }
}

extension View {
  func SmoothUIModule() -> some View {
    self.modifier(SmoothUIModuleModifier())
  }

  func widgetPopoverActivation(
    _ isPresented: Binding<Bool>,
    activation: KamidanaActivation,
    hoverState: WidgetPopoverHoverState
  ) -> some View {
    onHover { isHovered in
      hoverState.updateAnchorHover(
        isHovered,
        isPresented: isPresented,
        activation: activation
      )
    }
  }

  func widgetPopup<PopupContent: View>(
    isPresented: Binding<Bool>,
    activation: KamidanaActivation,
    hoverState: WidgetPopoverHoverState,
    @ViewBuilder content: @escaping () -> PopupContent
  ) -> some View {
    modifier(
      WidgetPopupModifier(
        isPresented: isPresented,
        activation: activation,
        hoverState: hoverState,
        popupContent: content
      )
    )
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
