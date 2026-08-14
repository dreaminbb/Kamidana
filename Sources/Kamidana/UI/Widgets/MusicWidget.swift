import SwiftUI

struct MusicWidget: View {
    @ObservedObject var musicManager: MusicPlayingManager
    var theme: Theme
    @Environment(\.compactMode) var compactMode: Bool

    @State private var rotation: Double = 0.0
    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0.0
    @State private var dragUUID = UUID()

    // 回転アニメーション用のタイマー
    let rotationTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        if !musicManager.title.isEmpty {
            // アイランドの領域全体を贅沢に使うUI
            HStack(alignment: .center, spacing: 40) {
                // 左側：特大サイズのアートワーク
                artworkView(size: 180)

                // 右側：曲情報、コントロール群、シークバー
                VStack(alignment: .leading, spacing: 24) {

                    // 1. タイトルとアーティスト
                    VStack(alignment: .leading, spacing: 8) {
                        Text(musicManager.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(2)
                        Text(musicManager.artist)
                            .font(.system(size: 18))
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(1)
                    }

                    // 2. スキップ・停止（再生/一時停止）ボタン
                    HStack(spacing: 40) {
                        Button(action: { musicManager.changeTrack(direction: .previous) }) {
                            NerdFontIcon(.backward)
                                .font(.system(size: 28))
                                .foregroundColor(theme.textPrimary)
                        }.buttonStyle(.plain)

                        Button(action: { musicManager.pauseMusic() }) {
                            NerdFontIcon(musicManager.isPlaying ? .pause : .play)
                                .font(.system(size: 44))
                                .foregroundColor(theme.success)
                        }.buttonStyle(.plain)

                        Button(action: { musicManager.changeTrack(direction: .next) }) {
                            NerdFontIcon(.forward)
                                .font(.system(size: 28))
                                .foregroundColor(theme.textPrimary)
                        }.buttonStyle(.plain)
                    }
                    .padding(.top, 8)

                    // 3. シークバーと時間（スキップ停止の下）
                    if musicManager.trackTime > 0 {
                        HStack(spacing: 12) {
                            Text(
                                formatTime(
                                    isDraggingSlider ? sliderValue : musicManager.currentPosition)
                            )
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(theme.textSecondary)
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
                                        // 🌟 AppleScriptでプレイヤーの時間が実際に更新されるまでのタイムラグを考慮し、
                                        // すぐに元の時間に引き戻されないよう、状態の解除を1秒遅延させます
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                            if self.dragUUID == currentUUID {
                                                isDraggingSlider = false
                                            }
                                        }
                                    }
                                }
                            )
                            .accentColor(theme.accent)

                            Text(formatTime(musicManager.trackTime))
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(theme.textSecondary)
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
            // 音楽が再生されていない時のUI
            VStack(spacing: 16) {
                NerdFontIcon(.music)
                    .font(.system(size: 48))
                    .foregroundColor(theme.textSecondary)
                Text("No Music Playing")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // アートワーク部分
    @ViewBuilder
    private func artworkView(size: CGFloat) -> some View {
        Group {
            if let artwork = musicManager.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    theme.surface
                    NerdFontIcon(.music)
                        .font(.system(size: size / 3))
                        .foregroundColor(theme.accent)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .rotationEffect(.degrees(rotation))
        .overlay(Circle().stroke(theme.surfaceBorder.opacity(0.5), lineWidth: 2))
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
