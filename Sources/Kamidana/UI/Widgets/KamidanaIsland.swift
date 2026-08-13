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

    @State private var islandSize: windowSizeRequirements = windowSizeRequirements( width: nil, height: nil)

    static let defaultHoveredSize = CGSize(width: 600 , height: 400)

    // 🌟 アプローチ1: サイズを計算して返す関数
    private func getIslandSize() -> CGSize {
        if !isHovered { return CGSize(width: 180, height: 32) }
        
        // Tabによるサイズ変更が必要な場合はここで計算できます
        if selectedTab == .btop {
            // もしTerminalタブの時だけサイズを変えたい場合はここで返す
            return CGSize(width: 800, height: 500)
        }

        // `??` 演算子を使えば、値がない場合(nil)のデフォルト値を1行で綺麗に書けます
        let w = islandSize.width ?? Self.defaultHoveredSize.width
        let h = islandSize.height ?? Self.defaultHoveredSize.height
        return CGSize(width: w, height: h)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isHovered {
                // 🌟 展開時のUI

                // 1. ブラウザ風のタブバー
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

                // 2. タブごとのコンテンツ（中身）
                Group {
                    switch selectedTab {
                    case .music:
                        VStack {
                            Spacer()
                            // 既存のMusicWidgetをとりあえず大きく表示（あとでカスタムも可能）
                            MusicWidget(musicManager: musicManager, theme: theme)
                                .scaleEffect(1.2)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    case .btop:
                        // 【重要】TerminalViewをここに埋め込む
                        TerminalView(executable: "/opt/homebrew/bin/btop", theme: theme)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .cornerRadius(12)
                            .padding(12)
                    }
                }

            } else {
                // 🌟 普段の小さなUI（折りたたみ時）
                HStack {
                    Image(systemName: "circle.grid.2x2.fill")
                        .foregroundColor(theme.primary)
                    Text(musicManager.title.isEmpty ? "Kamidana Island" : musicManager.title)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .foregroundColor(theme.textPrimary)
            }
        }
        // ホバー状態に応じて Island 自体のサイズをダイナミックに変更する！
        .frame(width: getIslandSize().width, height: getIslandSize().height) // 関数を呼び出して渡す
        .background(theme.background.opacity(0.8))
        .background(.ultraThinMaterial)
        .cornerRadius(isHovered ? 24 : 16)
        .overlay(
            RoundedRectangle(cornerRadius: isHovered ? 24 : 16)
                .stroke(theme.surfaceBorder, lineWidth: 1)
        )
        // 🌟 このアニメーションが Dynamic Island 特有の「ヌルッ」とした広がりを生みます
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }
}
