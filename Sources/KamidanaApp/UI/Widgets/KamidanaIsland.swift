import SwiftUI

struct windowSizeRequirements {
    var width: CGFloat?
    var height: CGFloat?
}

struct KamidanaIsland: View {
    @Environment(\.showsKamidanaWidgetSurface) private var showsWidgetSurface
    let centerWidgets: [WidgetInstance]
    let isBuiltInDisplay: Bool
    let builtInTopInset: CGFloat

    @StateObject private var interaction = WidgetInteractionController()
    @State private var selectedTab: WidgetInstance? = nil

    @State private var islandSize: windowSizeRequirements = windowSizeRequirements(
        width: nil, height: nil)

    static let defaultHoveredSize = CGSize(width: 600, height: 300)
    static let collapsedHeight: CGFloat = 32

    private func expandedIslandSize() -> CGSize {
        // If size change by tab is needed, calculate here
        if let tab = selectedTab {
            if tab.typeID == "terminal" {
                let terminal = tab.config as? TerminalWidgetConfig
                return CGSize(
                    width: CGFloat(terminal?.width ?? 700) + 24,
                    height: CGFloat(terminal?.height ?? 400) + 80
                )
            }
            if tab.typeID == "music" {
                let music = tab.config as? MusicWidgetConfig
                if music?.width != nil || music?.height != nil {
                    return CGSize(
                        width: CGFloat(music?.width ?? Self.defaultHoveredSize.width) + 24,
                        height: CGFloat(music?.height ?? Self.defaultHoveredSize.height) + 80
                    )
                }
            }
        }

        // Use `??` operator to provide fallback defaults cleanly when nil
        let w = islandSize.width ?? Self.defaultHoveredSize.width
        let h = islandSize.height ?? Self.defaultHoveredSize.height
        return CGSize(width: w, height: h)
    }

    var body: some View {
        let colors = ConfigManager.shared.currentConfig.colors
        let normalTheme = centerWidgets.first?.theme
        let expandedTheme = centerWidgets.first?.popupTheme ?? normalTheme
        let effectiveTheme = isHovered ? expandedTheme : normalTheme
        let interactionMotion = effectiveTheme?.motion ?? .standard
        let background = showsWidgetSurface ? (effectiveTheme?.background ?? Color(hex: colors.background)) : .clear
        let cornerRadius = effectiveTheme?.cornerRadius ?? (isHovered ? 24 : 16)
        let borderColor = effectiveTheme?.border.color.map(Color.init(hex:)) ?? Color(hex: colors.surfaceBorder)
        let borderWidth = showsWidgetSurface ? (effectiveTheme?.border.width ?? 1) : 0
        let expandedSize = expandedIslandSize()
        let verticalOffset = builtInVerticalOffset
        let material: AnyShapeStyle = {
            guard showsWidgetSurface else { return AnyShapeStyle(Color.clear) }
            switch effectiveTheme?.material {
            case .some(.none): return AnyShapeStyle(Color.clear)
            case .thin: return AnyShapeStyle(.thinMaterial)
            case .regular: return AnyShapeStyle(.regularMaterial)
            case .thick: return AnyShapeStyle(.thickMaterial)
            case .chrome: return AnyShapeStyle(.bar)
            case .some(.ultraThin), nil: return AnyShapeStyle(.ultraThinMaterial)
            }
        }()
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                if isHovered {
                    // Expanded UI

                    // 1. Browser-style tab bar
                    HStack(spacing: 12) {
                        ForEach(centerWidgets, id: \.id) { tab in
                            Button(action: {
                                if (tab.v1Animation ?? .dynamic) == .dynamic {
                                         withAnimation(interactionMotion.colorChange.resolvedAnimation()) {
                                        selectedTab = tab
                                    }
                                } else {
                                    selectedTab = tab
                                }
                            }) {
                                Text(tabName(for: tab))
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(
                                        selectedTab == tab
                                            ? Color(hex: colors.surfaceHighlight) : Color.clear
                                    )
                                    .foregroundColor(
                                        selectedTab == tab
                                            ? Color(hex: colors.textPrimary)
                                            : Color(hex: colors.textSecondary)
                                    )
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    Divider().background(Color(hex: colors.surfaceBorder))

                    // 2. Tab content
                    Group {
                        if let selected = selectedTab {
                            if let factory = WidgetRegistry.shared.factory(for: selected.typeID) {
                                factory.makeView(config: selected.config)
                                    .environment(\.theme, selected.theme)
                                    .environment(\.popupTheme, selected.popupTheme)
                                    .environment(\.kamidanaWidgetFormat, selected.v1Format)
                                    .environment(\.kamidanaWidgetActivation, selected.v1Activate)
                                    .kamidanaWidgetAnimation(selected.v1Animation)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                EmptyView()
                            }
                        }
                    }

                } else {
                    // Compact UI (collapsed state)
                    HStack(spacing: 6) {
                        if let defaultWidget = centerWidgets.first {
                            compactContent(for: defaultWidget)
                        }
                    }
                    .padding(
                        .horizontal,
                        10 + WidgetSurfaceMetrics.additionalHorizontalPadding
                    )
                }
            }
            .fixedSize(horizontal: !isHovered, vertical: !isHovered)
            .frame(
                width: isHovered ? expandedSize.width : nil,
                height: isHovered ? expandedSize.height : Self.collapsedHeight
            )
            .background(background)
            .background(material)
            .cornerRadius(cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
                )
            .offset(y: verticalOffset)
        }
        .frame(
            width: isHovered ? expandedSize.width : nil,
            height: isHovered
                ? expandedSize.height + max(0, verticalOffset)
                : Self.collapsedHeight
        )
        // This transparent container bridges the camera gap and the shifted expanded panel.
        .contentShape(Rectangle())
        // Spring animation providing smooth expansion
        .animation(isDynamic ? interactionMotion.expand.resolvedAnimation() : nil, value: isHovered)
        .onHover(perform: updateHover)
        .onTapGesture {
            guard activation == .click else { return }
            _ = interaction.activate(.click)
        }
        .onAppear {
            if selectedTab == nil {
                selectedTab = centerWidgets.first
            }
        }
    }

    private var isDynamic: Bool {
        (centerWidgets.first?.v1Animation ?? .dynamic) == .dynamic
    }

    private var activation: KamidanaActivation {
        centerWidgets.first?.v1Activate ?? .hover
    }

    private var builtInVerticalOffset: CGFloat {
        guard isBuiltInDisplay else { return 0 }
        return isHovered ? builtInTopInset : 0
    }

    private func updateHover(_ hovering: Bool) {
        let motion = centerWidgets.first?.popupTheme?.motion
            ?? centerWidgets.first?.theme?.motion
            ?? .standard
        interaction.updateAnchorHover(
            hovering,
            activation: activation,
            settleDelay: motion.hoverSettleDelay,
            dismissDelay: motion.popupDismissDelay
        )
    }

    private func setHovered(_ hovering: Bool) {
        if isDynamic {
            let motion = centerWidgets.first?.popupTheme?.motion
                ?? centerWidgets.first?.theme?.motion
                ?? .standard
            withAnimation(motion.expand.resolvedAnimation()) {
                interaction.setPresented(hovering)
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                interaction.setPresented(hovering)
            }
        }
    }

    private var isHovered: Bool { interaction.isPresented }

    private func tabName(for widget: WidgetInstance) -> String {
        return WidgetRegistry.shared.factory(for: widget.typeID)?.getTabName(config: widget.config)
            ?? "Unknown"
    }

    @ViewBuilder
    private func compactContent(for widget: WidgetInstance) -> some View {
        let colors = ConfigManager.shared.currentConfig.colors
        let theme = widget.theme

        if widget.typeID == "music" {
            let musicConfig = widget.config as? MusicWidgetConfig ?? MusicWidgetConfig()
            MusicNormalContent(
                config: musicConfig,
                format: widget.v1Format ?? musicConfig.normalFormat,
                artworkSize: 24
            )
            .environment(\.theme, theme)
            .environment(\.popupTheme, widget.popupTheme)
        } else if widget.typeID == "terminal" {
            FormattedWidgetLabel(
                format: widget.v1Format ?? "",
                values: [:],
                iconColor: theme?.iconForeground ?? Color(hex: colors.accent),
                textColor: theme?.foreground ?? Color(hex: colors.textPrimary)
            )
        } else if let factory = WidgetRegistry.shared.factory(for: widget.typeID) {
            factory.makeView(config: widget.config)
                .environment(\.theme, theme)
                .environment(\.popupTheme, widget.popupTheme)
                .environment(\.kamidanaWidgetFormat, widget.v1Format)
                .environment(\.kamidanaWidgetActivation, widget.v1Activate)
                .kamidanaWidgetAnimation(widget.v1Animation)
                .environment(\.showsKamidanaWidgetSurface, false)
        }
    }
}
