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
            HStack(spacing: 8) {
                // アートワーク（ホバー中はレコードのように回転）
                Group {
                    if let artwork = musicManager.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            theme.surface0
                            Image(systemName: "music.note")
                                .foregroundColor(theme.pink)
                        }
                    }
                }
                .frame(width: isHovered ? 40 : 20, height: isHovered ? 40 : 20)
                .clipShape(Circle()) // 丸く切り抜く
                .rotationEffect(.degrees(rotation))
                .overlay(
                    Circle().stroke(theme.surface2.opacity(0.5), lineWidth: 1)
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
                
                // 曲情報とコントロール
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(musicManager.title)
                            .font(.custom("Menlo", size: 10).bold()) // NerdFontを使う想定で等幅系フォント
                            .lineLimit(1)
                            .foregroundColor(theme.text)
                        
                        Spacer()
                        
                        // ホバー時のみ表示されるコントロールボタン群
                        if isHovered {
                            HStack(spacing: 8) {
                                Button(action: { musicManager.changeTrack(direction: .previous) }) {
                                    Image(systemName: "backward.fill")
                                        .foregroundColor(theme.text)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: { musicManager.pauseMusic() }) {
                                    Image(systemName: musicManager.isPlaying ? "pause.fill" : "play.fill")
                                        .foregroundColor(theme.green)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: { musicManager.changeTrack(direction: .next) }) {
                                    Image(systemName: "forward.fill")
                                        .foregroundColor(theme.text)
                                }
                                .buttonStyle(.plain)
                            }
                            .font(.system(size: 10))
                        }
                    }
                    
                    if isHovered {
                        // 拡張UI: アーティスト名とシークバー
                        Text(musicManager.artist)
                            .font(.custom("Menlo", size: 9))
                            .lineLimit(1)
                            .foregroundColor(theme.subtext0)
                        
                        // シークバー (Slider)
                        if musicManager.trackTime > 0 {
                            HStack(spacing: 4) {
                                Text(formatTime(isDraggingSlider ? sliderValue : musicManager.currentPosition))
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(theme.subtext1)
                                
                                Slider(value: Binding(
                                    get: {
                                        isDraggingSlider ? sliderValue : musicManager.currentPosition
                                    },
                                    set: { newValue in
                                        sliderValue = newValue
                                    }
                                ), in: 0...musicManager.trackTime, onEditingChanged: { editing in
                                    isDraggingSlider = editing
                                    if !editing {
                                        // ドラッグ終了時に再生位置を更新
                                        musicManager.seek(to: sliderValue)
                                    }
                                })
                                .controlSize(.mini)
                                .accentColor(theme.mauve)
                                
                                Text(formatTime(musicManager.trackTime))
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(theme.subtext1)
                            }
                        }
                    } else {
                        // 縮小UI: アーティスト名だけシンプルに
                        Text(musicManager.artist)
                            .font(.custom("Menlo", size: 9))
                            .lineLimit(1)
                            .foregroundColor(theme.subtext0)
                    }
                }
                .frame(maxWidth: isHovered ? 200 : 100, alignment: .leading)
            }
            .hyprlandModule(theme: theme)
            .onHover { hover in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isHovered = hover
                }
            }
            .onReceive(rotationTimer) { _ in
                // ホバー時かつ再生中のみ画像を回転させる
                if isHovered && musicManager.isPlaying {
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
