import SwiftUI

struct MusicWidget: View {
    @ObservedObject var musicManager: MusicPlayingManager
    var theme: Theme = .catppuccinMocha

    @State private var isHovered = false
    @State private var rotation: Double = 0.0
    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0.0

    // 回転アニメーション用のタイマー
    let rotationTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
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
                                theme.surface0
                                Image(systemName: "music.note").foregroundColor(theme.pink)
                            }
                        }
                    }
                    .frame(width: isHovered ? 64 : 20, height: isHovered ? 64 : 20)
                    .clipShape(Circle())
                    .rotationEffect(.degrees(rotation))
                    .overlay(Circle().stroke(theme.surface2.opacity(0.5), lineWidth: 1))

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
                    } else {
                        // 縮小時 (Dynamic Island コンパクトモード)
                        Text(musicManager.title)
                            .font(.custom("Menlo", size: 10).bold())
                            .foregroundColor(Color.white)
                            .lineLimit(1)
                            .frame(maxWidth: 120, alignment: .leading) // ノッチ幅を考慮
                        Spacer(minLength: 0)
                        Image(systemName: musicManager.isPlaying ? "waveform" : "pause.fill")
                            .font(.system(size: 10))
                            .foregroundColor(theme.pink)
                    }
                }
                .padding(.horizontal, isHovered ? 0 : 4)

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
                                .accentColor(theme.pink)

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
                                .foregroundColor(theme.green)
                            }.buttonStyle(.plain)

                            Button(action: { musicManager.changeTrack(direction: .next) }) {
                                Image(systemName: "forward.fill").font(.system(size: 16))
                                    .foregroundColor(Color.white)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(width: isHovered ? 350 : 200)  // 縮小時はノッチに合わせたサイズに
            .frame(height: isHovered ? nil : 32)
            .padding(isHovered ? 16 : 4)
            .background(Color.black) // Dynamic Islandの黒色
            .clipShape(RoundedRectangle(cornerRadius: isHovered ? 24 : 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
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
