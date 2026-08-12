import SwiftUI

struct MusicWidget: View {
    @ObservedObject var musicManager: MusicPlayingManager
    var theme: Theme = .catppuccinMocha
    @Environment(\.compactMode) var compactMode: Bool

    @State private var isHovered = false
    @State private var rotation: Double = 0.0
    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0.0

    // 回転アニメーション用のタイマー
    let rotationTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        // 高さは変えないため、28で固定する（コンパクトモードでもサイズ縮小しない）
        let closedSize: CGFloat = 28
        let paddingSize: CGFloat = 2
        
        if !musicManager.title.isEmpty {
            VStack(spacing: isHovered ? 16 : 0) {
                // 上段：アートワークと基本情報
                HStack(spacing: 12) {
                    // アートワーク
                    Group {
                        if let artwork = musicManager.artwork {
                            Image(nsImage: artwork)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            ZStack {
                                theme.surface
                                Image(systemName: "music.note").foregroundColor(theme.accent)
                            }
                        }
                    }
                    .frame(width: isHovered ? 64 : closedSize, height: isHovered ? 64 : closedSize)
                    .clipShape(Circle())
                    .rotationEffect(.degrees(rotation))
                    .overlay(Circle().stroke(theme.surfaceBorder.opacity(0.5), lineWidth: 1))

                    // テキスト情報
                    if isHovered {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(musicManager.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.white) // Dynamic Island風に白文字
                                .lineLimit(1)
                            Text(musicManager.artist)
                                .font(.system(size: 11))
                                .foregroundColor(Color.white.opacity(0.7))
                                .lineLimit(1)
                        }
                        Spacer()
                    } else if !compactMode {
                        // 通常モード（非ホバー時）：タイトルと波形アイコンを表示
                        Text(musicManager.title)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.white)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: musicManager.isPlaying ? "waveform" : "pause.fill")
                            .font(.system(size: 10))
                            .foregroundColor(theme.accent)
                            .padding(.trailing, 4)
                    }
                }

                // 下段：シークバーとコントロール（拡大時のみ）
                if isHovered {
                    VStack(spacing: 15) {
                        // シークバー
                        if musicManager.trackTime > 0 {
                            HStack(spacing: 8) {
                                Text(
                                    formatTime(
                                        isDraggingSlider
                                            ? sliderValue : musicManager.currentPosition)
                                )
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.7))

                                Slider(
                                    value: Binding(
                                        get: {
                                            isDraggingSlider
                                                ? sliderValue : musicManager.currentPosition
                                        },
                                        set: { sliderValue = $0 }
                                    ), in: 0...musicManager.trackTime,
                                    onEditingChanged: { editing in
                                        isDraggingSlider = editing
                                        if !editing { musicManager.seek(to: sliderValue) }
                                    }
                                )
                                .controlSize(.mini)
                                .accentColor(theme.accent)

                                Text(formatTime(musicManager.trackTime))
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(Color.white.opacity(0.7))
                            }
                        }

                        // コントロール
                        HStack(spacing: 24) {
                            Button(action: { musicManager.changeTrack(direction: .previous) }) {
                                Image(systemName: "backward.fill").font(.system(size: 16))
                                    .foregroundColor(Color.white)
                            }.buttonStyle(.plain)

                            Button(action: { musicManager.pauseMusic() }) {
                                Image(
                                    systemName: musicManager.isPlaying ? "pause.fill" : "play.fill"
                                )
                                .font(.system(size: 24))
                                .foregroundColor(theme.success)
                            }.buttonStyle(.plain)

                            Button(action: { musicManager.changeTrack(direction: .next) }) {
                                Image(systemName: "forward.fill").font(.system(size: 16))
                                    .foregroundColor(Color.white)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(width: isHovered ? 350 : (compactMode ? closedSize : 160))
            .frame(height: isHovered ? nil : closedSize)
            .padding(isHovered ? 16 : paddingSize)
            .background((isHovered || !compactMode) ? Color.black : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: isHovered ? 24 : 16, style: .continuous))
            .shadow(color: (isHovered || !compactMode) ? Color.black.opacity(0.3) : Color.clear, radius: 10, x: 0, y: 5)
            // ホバー時のアニメーション
            .onHover { hover in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)) {
                    isHovered = hover
                }
            }
            .onReceive(rotationTimer) { _ in
                if musicManager.isPlaying {
                    rotation += 2.0
                    if rotation >= 360 { rotation = 0 }
                }
            }
        }
    }

    // 秒数を mm:ss 形式にフォーマットするユーティリティ
    private func formatTime(_ time: Double) -> String {
        guard !time.isNaN && !time.isInfinite else { return "0:00" }
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
