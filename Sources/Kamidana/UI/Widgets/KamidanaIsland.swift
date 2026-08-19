import SwiftUI

struct windowSizeRequirements {
    var width: CGFloat?
    var height: CGFloat?
}

struct KamidanaIsland: View {
    @EnvironmentObject var musicManager: MusicPlayingManager
    @Environment(\.showsKamidanaWidgetSurface) private var showsWidgetSurface
    let centerWidgets: [WidgetInstance]

    @State private var isHovered = false
    @State private var selectedTab: WidgetInstance? = nil

    @State private var islandSize: windowSizeRequirements = windowSizeRequirements(
        width: nil, height: nil)

    static let defaultHoveredSize = CGSize(width: 600, height: 300)
    static let terminalHoveredSize = CGSize(width: 800, height: 500)

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
        let defaultStyle = centerWidgets.first?.v1Style
        let background = defaultStyle?.background ?? colors.background
        let backgroundOpacity = showsWidgetSurface ? (defaultStyle?.opacity ?? 0.8) : 0
        let cornerRadius = defaultStyle?.cornerRadius ?? (isHovered ? 24 : 16)
        let borderColor = defaultStyle?.border?.color ?? colors.surfaceBorder
        let borderWidth = showsWidgetSurface ? (defaultStyle?.border?.width ?? 1) : 0
        let material: AnyShapeStyle = {
            guard showsWidgetSurface else { return AnyShapeStyle(Color.clear) }
            switch defaultStyle?.material {
            case .some(.none): return AnyShapeStyle(Color.clear)
            case .thin: return AnyShapeStyle(.thinMaterial)
            case .regular: return AnyShapeStyle(.regularMaterial)
            case .thick: return AnyShapeStyle(.thickMaterial)
            case .chrome: return AnyShapeStyle(.bar)
            case .some(.ultraThin), nil: return AnyShapeStyle(.ultraThinMaterial)
            }
        }()
        VStack(spacing: 0) {
            if isHovered {
                // Expanded UI

                // 1. Browser-style tab bar
                HStack(spacing: 12) {
                    ForEach(centerWidgets, id: \.id) { tab in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = tab
                                print("islandsize \(islandSize)")
                            }

                        }) {
                            Text(tabName(for: tab))
                                .font(.system(size: 14, weight: .bold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(
                                    selectedTab == tab ? Color(hex: colors.surfaceHighlight) : Color.clear
                                )
                                .foregroundColor(
                                    selectedTab == tab ? Color(hex: colors.textPrimary) : Color(hex: colors.textSecondary)
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
                                .environment(\.kamidanaWidgetFormat, selected.v1Format)
                                .environment(\.kamidanaWidgetActivation, selected.v1Activate)
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
            width: isHovered ? expandedIslandSize().width : nil,
            height: isHovered ? expandedIslandSize().height : 32
        )
        .background(Color(hex: background).opacity(backgroundOpacity))
        .background(material)
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color(hex: borderColor), lineWidth: borderWidth)
        )
        // Spring animation providing smooth expansion
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .onAppear {
            if selectedTab == nil {
                selectedTab = centerWidgets.first
            }
        }
    }

    private func tabName(for widget: WidgetInstance) -> String {
        return WidgetRegistry.shared.factory(for: widget.typeID)?.getTabName(config: widget.config) ?? "Unknown"
    }

    @ViewBuilder
    private func compactContent(for widget: WidgetInstance) -> some View {
        let colors = ConfigManager.shared.currentConfig.colors
        let style = widget.v1Style

        if widget.typeID == "music" {
            if !musicManager.title.isEmpty, let artwork = musicManager.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
            }

            let musicConfig = widget.config as? MusicWidgetConfig ?? MusicWidgetConfig()
            FormattedWidgetLabel(
                format: widget.v1Format ?? "{icon} {title}",
                values: [
                    "icon": musicConfig.defaultIcon,
                    "title": musicManager.title,
                    "artist": musicManager.artist
                ],
                iconColor: Color(hex: style?.iconColor ?? musicConfig.defaultIconColor),
                textColor: Color(hex: style?.color ?? colors.textPrimary)
            )
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
                .environment(\.kamidanaWidgetFormat, widget.v1Format)
                .environment(\.kamidanaWidgetActivation, widget.v1Activate)
                .environment(\.showsKamidanaWidgetSurface, false)
        }
    }
}
