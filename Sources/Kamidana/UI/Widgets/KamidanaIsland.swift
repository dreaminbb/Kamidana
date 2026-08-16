import SwiftUI

struct windowSizeRequirements {
    var width: CGFloat?
    var height: CGFloat?
}

struct KamidanaIsland: View {
    @ObservedObject var musicManager: MusicPlayingManager

    @State private var isHovered = false
    @State private var selectedTab: AnyWidgetConfig? = ConfigManager.shared.currentConfig.center.first

    @State private var rotation: Double = 0.0
    @State private var islandSize: windowSizeRequirements = windowSizeRequirements(
        width: nil, height: nil)

    let rotationTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    static let defaultHoveredSize = CGSize(width: 600, height: 300)
    static let defaultCompactSize = CGSize(width: 180, height: 32)
    static let terminalHoveredSize = CGSize(width: 800, height: 500)

    // Calculate and return size
    private func getIslandSize() -> CGSize {
        if !isHovered { return Self.defaultCompactSize }

        // If size change by tab is needed, calculate here
        if let tab = selectedTab {
            if case .terminal(_) = tab {
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
        VStack(spacing: 0) {
            if isHovered {
                // Expanded UI

                // 1. Browser-style tab bar
                HStack(spacing: 12) {
                    ForEach(ConfigManager.shared.currentConfig.center, id: \.self) { tab in
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
                        switch selected {
                        case .music(let conf):
                            MusicWidget(musicManager: musicManager, config: conf)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .terminal(let conf):
                            TerminalView(executable: conf.terminalPath)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .cornerRadius(12)
                                .padding(12)
                        default:
                            EmptyView()
                        }
                    }
                }

            } else {
                // Compact UI (collapsed state)
                HStack(spacing: 0) {
                    if !musicManager.title.isEmpty, let artwork = musicManager.artwork {
                        // Display artwork when music is playing
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .onReceive(rotationTimer) { _ in
                                if musicManager.isPlaying {
                                    rotation += 1.5
                                    if rotation >= 360 { rotation = 0 }
                                }
                            }
                            .rotationEffect(.degrees(rotation))
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                            .padding(.leading, 10)

                        // TODO: Add audio visualizer here

                    } else {
                        // Default icon when no music or artwork is available
                        let musicConfig = ConfigManager.shared.currentConfig.center.compactMap { w -> MusicWidgetConfig? in if case .music(let c) = w { return c }; return nil }.first ?? MusicWidgetConfig()
                        NerdFontIcon(musicConfig.defaultIcon)
                            .foregroundColor(Color(hex: musicConfig.defaultIconColor))
                    }

                    Spacer()
                    Text(musicManager.title.isEmpty ? "" : musicManager.title)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()
                }
                .foregroundColor(Color(hex: colors.textPrimary))
                .padding(.leading, 3)
            }
        }
        // Dynamically change island size based on hover state
        .frame(width: getIslandSize().width, height: getIslandSize().height)  // Pass computed size
        .background(Color(hex: colors.background).opacity(0.8))
        .background(.ultraThinMaterial)
        .cornerRadius(isHovered ? 24 : 16)
        .overlay(
            RoundedRectangle(cornerRadius: isHovered ? 24 : 16)
                .stroke(Color(hex: colors.surfaceBorder), lineWidth: 1)
        )
        // Spring animation providing smooth expansion
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }

    private func tabName(for widget: AnyWidgetConfig) -> String {
        switch widget {
        case .music: return "Music"
        case .terminal(let conf): return conf.name
        default: return "Tab"
        }
    }
}
