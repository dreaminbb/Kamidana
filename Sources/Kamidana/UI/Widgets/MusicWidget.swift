import SwiftUI

struct MusicWidget: View {
    @ObservedObject var musicManager: MusicPlayingManager
    @Environment(\.compactMode) var compactMode: Bool

    @State private var rotation: Double = 0.0
    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0.0
    @State private var dragUUID = UUID()

    let config: MusicWidgetConfig

    // Timer for rotation animation
    let rotationTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        let colors = ConfigManager.shared.currentConfig.colors
        if !musicManager.title.isEmpty {
            // UI utilizing full island area
            HStack(alignment: .center, spacing: 40) {
                // Left: Large artwork
                artworkView(size: 180)

                // Right: Track info, controls, and seek bar
                VStack(spacing: 24) {

                    // 1. Title and artist
                    VStack(spacing: 8) {
                        Text(musicManager.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: colors.textPrimary))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        Text(musicManager.artist)
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: colors.textSecondary))
                            .lineLimit(1)
                    }

                    // 2. Skip and play/pause controls
                    HStack(spacing: 40) {
                        Button(action: { musicManager.changeTrack(direction: .previous) }) {
                            NerdFontIcon(config.backwardIcon, size: 35)
                                .foregroundColor(Color(hex: colors.textPrimary))
                        }.buttonStyle(.plain)

                        Button(action: { musicManager.pauseMusic() }) {
                            NerdFontIcon(musicManager.isPlaying ? config.pauseIcon : config.playIcon, size: 35)
                                .foregroundColor(Color(hex: colors.success))
                        }.buttonStyle(.plain)

                        Button(action: { musicManager.changeTrack(direction: .next) }) {
                            NerdFontIcon(config.forwardIcon, size: 35)
                                .foregroundColor(Color(hex: colors.textPrimary))
                        }.buttonStyle(.plain)
                    }
                    .padding(.top, 8)

                    // 3. Seek bar and time display (below playback controls)
                    if musicManager.trackTime > 0 {
                        HStack(spacing: 12) {
                            Text(
                                formatTime(
                                    isDraggingSlider ? sliderValue : musicManager.currentPosition)
                            )
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(Color(hex: colors.textSecondary))
                            .frame(width: 45, alignment: .leading)

                            Slider(
                                value: Binding(
                                    get: {
                                        isDraggingSlider
                                            ? sliderValue : musicManager.currentPosition
                                    },
                                    set: { sliderValue = $0 }
                                ), in: 0...musicManager.trackTime,
                                onEditingChanged: { editing in
                                    if editing {
                                        isDraggingSlider = true
                                        dragUUID = UUID()
                                    } else {
                                        musicManager.seek(to: sliderValue)
                                        let currentUUID = dragUUID
                                        // Delay clearing drag state by 1 second to account for time lag
                                        // before AppleScript updates player position, preventing slider snapback
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                            if self.dragUUID == currentUUID {
                                                isDraggingSlider = false
                                            }
                                        }
                                    }
                                }
                            )
                            .accentColor(Color(hex: colors.accent))

                            Text(formatTime(musicManager.trackTime))
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(Color(hex: colors.textSecondary))
                                .frame(width: 45, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onReceive(rotationTimer) { _ in
                if musicManager.isPlaying {
                    rotation += 1.5
                    if rotation >= 360 { rotation = 0 }
                }
            }
        } else {
            // UI when no music is playing
            VStack(spacing: 16) {
                NerdFontIcon(config.defaultIcon)
                    .font(.system(size: 48))
                    .foregroundColor(Color(hex: config.defaultIconColor))
                Text("No Music Playing")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: colors.textSecondary))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // Artwork view
    @ViewBuilder
    private func artworkView(size: CGFloat) -> some View {
        let colors = ConfigManager.shared.currentConfig.colors
        Group {
            if let artwork = musicManager.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color(hex: colors.surface)
                    NerdFontIcon(config.defaultIcon)
                        .font(.system(size: size / 3))
                        .foregroundColor(Color(hex: config.defaultIconColor))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .rotationEffect(.degrees(rotation))
        .overlay(Circle().stroke(Color(hex: colors.surfaceBorder).opacity(0.5), lineWidth: 2))
    }

    // Utility to format seconds into mm:ss format
    private func formatTime(_ time: Double) -> String {
        guard !time.isNaN && !time.isInfinite else { return "0:00" }
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
