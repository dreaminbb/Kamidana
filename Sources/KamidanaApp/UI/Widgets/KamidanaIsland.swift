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

    @State private var isHovered = false
    @State private var selectedTab: WidgetInstance? = nil
    @State private var pendingHoverCloseID: UUID?

    @State private var islandSize: windowSizeRequirements = windowSizeRequirements(
        width: nil, height: nil)

    static let defaultHoveredSize = CGSize(width: 600, height: 300)
    static let terminalHoveredSize = CGSize(width: 800, height: 500)
    static let collapsedHeight: CGFloat = 32

    private func expandedIslandSize() -> CGSize {
        // If size change by tab is needed, calculate here
        if let tab = selectedTab {
            if tab.typeID == "terminal" {
                return Self.terminalHoveredSize
            }
        }

        // Use `??` operator to provide fallback defaults cleanly when nil
        let w = islandSize.width ?? Self.defaultHoveredSize.width
        let h = islandSize.height ?? Self.defaultHoveredSize.height
        return CGSize(width: w, height: h)
    }

    var body: some View {
        let colors = ConfigManager.shared.currentConfig.colors
        let normalStyle = centerWidgets.first?.v1Style
        let expandedStyle = centerWidgets.first?.v1PopupStyle ?? normalStyle
        let effectiveStyle = isHovered ? expandedStyle : normalStyle
        let background = effectiveStyle?.background ?? colors.background
        let backgroundOpacity = showsWidgetSurface ? (effectiveStyle?.opacity ?? 0.8) : 0
        let cornerRadius = effectiveStyle?.cornerRadius ?? (isHovered ? 24 : 16)
        let borderColor = effectiveStyle?.border?.color ?? colors.surfaceBorder
        let borderWidth = showsWidgetSurface ? (effectiveStyle?.border?.width ?? 1) : 0
        let expandedSize = expandedIslandSize()
        let verticalOffset = builtInVerticalOffset
        let material: AnyShapeStyle = {
            guard showsWidgetSurface else { return AnyShapeStyle(Color.clear) }
            switch effectiveStyle?.material {
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
                                if (tab.v1Motion ?? .dynamic) == .dynamic {
                                    withAnimation(.easeInOut(duration: 0.2)) {
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
                                    .environment(\.kamidanaV1Style, selected.v1Style)
                                    .environment(\.kamidanaPopupStyle, selected.v1PopupStyle)
                                    .environment(\.kamidanaWidgetFormat, selected.v1Format)
                                    .environment(\.kamidanaWidgetActivation, selected.v1Activate)
                                    .kamidanaWidgetMotion(selected.v1Motion)
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
            .background(Color(hex: background).opacity(backgroundOpacity))
            .background(material)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color(hex: borderColor), lineWidth: borderWidth)
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
        .animation(isDynamic ? .spring(response: 0.5, dampingFraction: 0.7) : nil, value: isHovered)
        .onHover(perform: updateHover)
        .onAppear {
            if selectedTab == nil {
                selectedTab = centerWidgets.first
            }
        }
    }

    private var isDynamic: Bool {
        (centerWidgets.first?.v1Motion ?? .dynamic) == .dynamic
    }

    private var builtInVerticalOffset: CGFloat {
        guard isBuiltInDisplay else { return 0 }
        return isHovered ? builtInTopInset : 0
    }

    private func updateHover(_ hovering: Bool) {
        if hovering {
            pendingHoverCloseID = nil
            setHovered(true)
            return
        }

        let closeID = UUID()
        pendingHoverCloseID = closeID
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard pendingHoverCloseID == closeID else { return }
            setHovered(false)
        }
    }

    private func setHovered(_ hovering: Bool) {
        if isDynamic {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isHovered = hovering
            }
        }
    }

    private func tabName(for widget: WidgetInstance) -> String {
        return WidgetRegistry.shared.factory(for: widget.typeID)?.getTabName(config: widget.config)
            ?? "Unknown"
    }

    @ViewBuilder
    private func compactContent(for widget: WidgetInstance) -> some View {
        let colors = ConfigManager.shared.currentConfig.colors
        let style = widget.v1Style

        if widget.typeID == "music" {
            let musicConfig = widget.config as? MusicWidgetConfig ?? MusicWidgetConfig()
            MusicNormalContent(
                config: musicConfig,
                format: widget.v1Format ?? musicConfig.normalFormat,
                artworkSize: 24
            )
            .environment(\.kamidanaV1Style, style)
        } else if widget.typeID == "terminal" {
            FormattedWidgetLabel(
                format: widget.v1Format ?? "",
                values: [:],
                iconColor: Color(hex: style?.iconColor ?? colors.accent),
                textColor: Color(hex: style?.color ?? colors.textPrimary)
            )
        } else if let factory = WidgetRegistry.shared.factory(for: widget.typeID) {
            factory.makeView(config: widget.config)
                .environment(\.kamidanaV1Style, style)
                .environment(\.kamidanaPopupStyle, widget.v1PopupStyle)
                .environment(\.kamidanaWidgetFormat, widget.v1Format)
                .environment(\.kamidanaWidgetActivation, widget.v1Activate)
                .kamidanaWidgetMotion(widget.v1Motion)
                .environment(\.showsKamidanaWidgetSurface, false)
        }
    }
}
