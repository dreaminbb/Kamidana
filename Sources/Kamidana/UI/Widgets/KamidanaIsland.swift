import SwiftUI

enum IslandTab: String, CaseIterable {
    case music = "Music"
    case btop = "Btop"
}

struct windowSizeRequirements {
    var width: CGFloat?
    var height: CGFloat?
}

struct KamidanaIsland: View {
    var theme: Theme
    @ObservedObject var musicManager: MusicPlayingManager

    @State private var isHovered = false
    @State private var selectedTab: IslandTab = .music

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
        if selectedTab == .btop {
            // If changing size only for the Terminal tab, return here
            return Self.terminalHoveredSize
        }

        // Use `??` operator to provide fallback defaults cleanly when nil
        let w = islandSize.width ?? Self.defaultHoveredSize.width
        let h = islandSize.height ?? Self.defaultHoveredSize.height
        return CGSize(width: w, height: h)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isHovered {
                // Expanded UI

                // 1. Browser-style tab bar
                HStack(spacing: 12) {
                    ForEach(IslandTab.allCases, id: \.self) { tab in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = tab
                                print("islandsize \(islandSize)")
                            }

                        }) {
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: .bold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(
                                    selectedTab == tab ? theme.surfaceHighlight : Color.clear
                                )
                                .foregroundColor(
                                    selectedTab == tab ? theme.textPrimary : theme.textSecondary
                                )
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 8)

                Divider().background(theme.surfaceBorder)

                // 2. Tab content
                Group {
                    switch selectedTab {
                    case .music:
                        // Place MusicWidget directly configured to expand across the island
                        MusicWidget(musicManager: musicManager, theme: theme)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                    case .btop:
                        // Embed TerminalView here
                        TerminalView(executable: ConfigManager.shared.currentConfig.systemControl.terminalPath, theme: theme)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .cornerRadius(12)
                            .padding(12)
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
                        NerdFontIcon("󰕰")
                            .foregroundColor(theme.primary)
                    }

                    Spacer()
                    Text(musicManager.title.isEmpty ? "" : musicManager.title)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()
                }
                .foregroundColor(theme.textPrimary)
                .padding(.leading, 3)
            }
        }
        // Dynamically change island size based on hover state
        .frame(width: getIslandSize().width, height: getIslandSize().height)  // Pass computed size
        .background(theme.background.opacity(0.8))
        .background(.ultraThinMaterial)
        .cornerRadius(isHovered ? 24 : 16)
        .overlay(
            RoundedRectangle(cornerRadius: isHovered ? 24 : 16)
                .stroke(theme.surfaceBorder, lineWidth: 1)
        )
        // Spring animation providing smooth expansion
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }
}
