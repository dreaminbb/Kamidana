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
                                .foregroundColor(theme.text)
                                .lineLimit(1)
                            Text(musicManager.artist)
                                .font(.system(size: 11))
                                .foregroundColor(theme.subtext0)
                                .lineLimit(1)
                        }
                        Spacer()
                    } else {
                        // 縮小時
                        Text(musicManager.title)
                            .font(.custom("Menlo", size: 10).bold())
                            .foregroundColor(theme.text)
                            .lineLimit(1)
                            .frame(maxWidth: 80, alignment: .leading)
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
                                .foregroundColor(theme.subtext1)

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
                                .accentColor(theme.mauve)

                                Text(formatTime(musicManager.trackTime))
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(theme.subtext1)
                            }
                        }

                        // コントロール
                        HStack(spacing: 24) {
                            Button(action: { musicManager.changeTrack(direction: .previous) }) {
                                Image(systemName: "backward.fill").font(.system(size: 16))
                                    .foregroundColor(theme.text)
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
                                    .foregroundColor(theme.text)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(width: isHovered ? 350 : nil)  // 拡大時は幅を固定して大きく見せる
            .padding(isHovered ? 12 : 0)  // 拡大時だけ内側に余白を追加して四方に広げる
            .SmoothUIModule(theme: theme)
            .cornerRadius(20)
            .onHover { hover in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
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
