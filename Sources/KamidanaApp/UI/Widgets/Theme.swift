import SwiftUI

public struct Theme: Equatable {
    public var background: Color
    public var foreground: Color
    public var iconForeground: Color
    public var padding: KamidanaInsets
    public var spacing: CGFloat
    public var cornerRadius: CGFloat
    public var border: KamidanaBorder
    public var shadow: KamidanaShadow?
    public var material: KamidanaMaterial
    public var animation: KamidanaAnimation?
    public var hoverTheme: HoverTheme?
    public var pressedTheme: PressedTheme?
    public var motion: Motion
    public var severityColors: SeverityColors

    public struct Motion: Equatable {
        public var hover: KamidanaAnimation
        public var expand: KamidanaAnimation
        public var colorChange: KamidanaAnimation
        public var hoverSettleDelay: TimeInterval
        public var popupDismissDelay: TimeInterval

        public init(
            hover: KamidanaAnimation = KamidanaAnimation(
                preset: .easeInOut, durationSeconds: 0.15),
            expand: KamidanaAnimation = KamidanaAnimation(
                preset: .spring, damping: 0.85, response: 0.3),
            colorChange: KamidanaAnimation = KamidanaAnimation(
                preset: .easeInOut, durationSeconds: 0.2),
            hoverSettleDelay: TimeInterval = 0.04,
            popupDismissDelay: TimeInterval = 0.3
        ) {
            self.hover = hover
            self.expand = expand
            self.colorChange = colorChange
            self.hoverSettleDelay = hoverSettleDelay
            self.popupDismissDelay = popupDismissDelay
        }

        public static let standard = Motion()

        func animation(for state: WidgetInteractionState) -> KamidanaAnimation {
            switch state {
            case .idle, .pressed: return colorChange
            case .hover: return hover
            }
        }
    }

    public struct SeverityColors: Equatable {
        public var normal: Color
        public var warning: Color
        public var critical: Color

        public init(
            normal: Color = .primary,
            warning: Color = .primary,
            critical: Color = .primary
        ) {
            self.normal = normal
            self.warning = warning
            self.critical = critical
        }

        func color(for severity: WidgetSeverity) -> Color {
            switch severity {
            case .normal: return normal
            case .warning: return warning
            case .critical: return critical
            }
        }
    }

    public struct HoverTheme: Equatable {
        public var background: Color?
        public var foreground: Color?
        public var iconForeground: Color?
        public var border: KamidanaBorder?
        public var shadow: KamidanaShadow?
        public var opacity: Double?
        public var scale: CGFloat

        public init(
            background: Color? = nil,
            foreground: Color? = nil,
            iconForeground: Color? = nil,
            border: KamidanaBorder? = nil,
            shadow: KamidanaShadow? = nil,
            opacity: Double? = nil,
            scale: CGFloat = 1
        ) {
            self.background = background
            self.foreground = foreground
            self.iconForeground = iconForeground
            self.border = border
            self.shadow = shadow
            self.opacity = opacity
            self.scale = scale
        }
    }

    public struct PressedTheme: Equatable {
        public var background: Color?
        public var foreground: Color?
        public var iconForeground: Color?
        public var border: KamidanaBorder?
        public var shadow: KamidanaShadow?
        public var opacity: Double?
        public var scale: CGFloat

        public init(
            background: Color? = nil,
            foreground: Color? = nil,
            iconForeground: Color? = nil,
            border: KamidanaBorder? = nil,
            shadow: KamidanaShadow? = nil,
            opacity: Double? = nil,
            scale: CGFloat = 1
        ) {
            self.background = background
            self.foreground = foreground
            self.iconForeground = iconForeground
            self.border = border
            self.shadow = shadow
            self.opacity = opacity
            self.scale = scale
        }
    }

    public init(
        background: Color = .clear,
        foreground: Color = .primary,
        iconForeground: Color = .primary,
        padding: KamidanaInsets = KamidanaInsets(),
        spacing: CGFloat = 8,
        cornerRadius: CGFloat = 0,
        border: KamidanaBorder = KamidanaBorder(width: 0, color: nil),
        shadow: KamidanaShadow? = nil,
        material: KamidanaMaterial = .ultraThin,
        animation: KamidanaAnimation? = nil,
        hoverTheme: HoverTheme? = nil,
        pressedTheme: PressedTheme? = PressedTheme(opacity: 0.88),
        motion: Motion = .standard,
        severityColors: SeverityColors = SeverityColors()
    ) {
        self.background = background
        self.foreground = foreground
        self.iconForeground = iconForeground
        self.padding = padding
        self.spacing = spacing
        self.cornerRadius = cornerRadius
        self.border = border
        self.shadow = shadow
        self.material = material
        self.animation = animation
        self.hoverTheme = hoverTheme
        self.pressedTheme = pressedTheme
        self.motion = motion
        self.severityColors = severityColors
    }
}
