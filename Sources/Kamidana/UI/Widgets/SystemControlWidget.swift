import SwiftUI

struct SystemControlWidget: View {
    var theme: Theme
    let systemController = SystemController()

    @State private var isHovered = false
    @Environment(\.compactMode) var compactMode: Bool  // 👈 他のウィジェットとパディングを合わせるために追加
    @Environment(\.openWindow) private var openWindow

    func openBtopTerminalWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1500, height: 1000),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // 💡 半透明・クールな見た目にするための重要設定
        window.titlebarAppearsTransparent = true  // タイトルバーを透明化
        window.titleVisibility = .hidden  // タイトル文字を隠す
        window.backgroundColor = .clear  // ウィンドウ自体の背景色を透明に
        window.isOpaque = false  // 透過を許可（これがないとすりガラス効果が出ません）
        window.center()  // 画面の中央に配置

        // 4. SwiftUIのViewをAppKitのウィンドウにはめ込む
        // ここで半透明やすりガラスの装飾をつけます
        let terminalUI = TerminalView(executable: "/opt/homebrew/bin/btop", theme: theme)
            .background(theme.background.opacity(0.8))
            .background(.ultraThinMaterial)  // すりガラス効果

        // NSHostingView が SwiftUI と AppKit(NSWindow) を繋ぐ橋渡し役になります
        window.contentView = NSHostingView(rootView: terminalUI)
        NSApplication.shared.activate(ignoringOtherApps: true)

        // 5. ウィンドウを一番手前に表示してフォーカスを当てる
        window.makeKeyAndOrderFront(nil)

    }

    var body: some View {
        // ベースのアイコン（他のWiFiUIなどと全く同じレイアウト・高さになります）
        HStack(spacing: 4) {
            NerdFontIcon(.appleLogo)
                .foregroundColor(theme.secondary)
                .font(.system(size: 14))
                .frame(width: 20, alignment: .center)  // 🌟 幅を20pxに広げて中央揃えを強制
        }
        .SmoothUIModule(theme: theme)  // 👈 これで他のUIと位置・サイズが完全に一致します
        // ホバー時に展開するメニューは「背景（裏側）」として配置します
        .background(
            Group {
                if isHovered {
                    VStack(alignment: .leading, spacing: 4) {
                        // 🌟 ボトルの首（細い部分）：
                        Color.clear
                            .frame(width: compactMode ? 36 : 44, height: 28)  // ベース幅(20 + 左右padding)に合わせる

                        // 🌟 ボトルの胴体（太く展開する部分）：
                        VStack(alignment: .leading, spacing: 12) {

                            menuButton(
                                icon: .laptop, color: theme.info, text: "About this Mac"
                            ) {
                                let _ = systemController.showAboutThisMac()
                            }

                            menuButton(icon: .bed, color: theme.info, text: "Sleep") {
                                let _ = systemController.sleepSystem()
                            }

                            menuButton(icon: .power, color: theme.danger, text: "Shutdown") {
                                let _ = systemController.shutdownSystem()
                            }

                            menuButton(
                                icon: .arrowClockwise, color: theme.warning,
                                text: "Reboot"
                            ) {
                                let _ = systemController.rebootSystem()
                            }

                            menuButton(
                                icon: .exit, color: theme.primary,
                                text: "Logout"
                            ) {
                                let _ = systemController.logoutSystem()
                            }

                            menuButton(icon: .lock, color: theme.accent, text: "Screen Lock") {
                                let _ = systemController.lockScreen()
                            }

                        }
                        // 🌟 左側のパディングをSmoothUIModule（ホームボタン側）のパディングと完全に同じ値にすることで縦軸を揃える！
                        .padding(.leading, compactMode ? 8 : 12)
                        .padding(.trailing, 16)
                        .padding(.vertical, 12)
                        .background(theme.background)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(theme.surfaceHighlight, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)
                    }
                    //  fixedSize()をつけることで、アイコンの幅に制限されずテキストに合わせて展開
                    .fixedSize()
                    // ホームボタン（左上）を起点として、下へ伸びる形のアニメーション
                    .transition(.scale(scale: 0.01, anchor: .topLeading).combined(with: .opacity))
                }
            }, alignment: .topLeading
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .zIndex(100)  // 展開時に他のウィジェットの下に隠れないようにする
    }

    // 🌟 ボタンのデザインを共通化してコードをスッキリさせる（コンパイラのエラーも防げます）
    private func menuButton(
        icon: NerdFontIconType, color: Color, text: String, action: @escaping () -> Void
    )
        -> some View
    {
        Button(action: action) {
            HStack(spacing: 10) {
                NerdFontIcon(icon)
                    .foregroundColor(color)
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 20, alignment: .center)

                Text(text)
                    .foregroundColor(theme.textPrimary)
            }
        }
        .buttonStyle(.plain)
    }
}
