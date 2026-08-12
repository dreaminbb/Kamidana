import SwiftUI

struct SystemControlWidget: View {
    var theme: Theme
    let systemController = SystemController()

    @State private var isHovered = false
    @Environment(\.compactMode) var compactMode: Bool  // 👈 他のウィジェットとパディングを合わせるために追加

    var body: some View {
        // ベースのアイコン（他のWiFiUIなどと全く同じレイアウト・高さになります）
        HStack(spacing: 4) {
            Image(systemName: "apple.logo")
                .foregroundColor(theme.mauve)
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

                            Button(action: {
                                let _ = systemController.showAboutThisMac()
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "laptopcomputer")
                                        .foregroundColor(theme.teal)  // ユーザーが追加したテーマ色を維持
                                        .font(.system(size: 14, weight: .bold))
                                        .frame(width: 20, alignment: .center)

                                    Text("About this Mac")
                                        .foregroundColor(theme.text)
                                }
                            }
                            .buttonStyle(.plain)

                            // sleep
                            Button(action: {
                                let _ = systemController.sleepSystem()
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "bed.double.fill")
                                        .foregroundColor(theme.sapphire)
                                        .font(.system(size: 14, weight: .bold))
                                        .frame(width: 20, alignment: .center)  // 🌟 電源アイコンを中心に20pxの枠で揃える

                                    Text("Sleep")
                                        .foregroundColor(theme.text)
                                }
                            }
                            .buttonStyle(.plain)

                            // shutdown
                            Button(action: {
                                let _ = systemController.shutdownSystem()
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "power")
                                        .foregroundColor(theme.red)
                                        .font(.system(size: 14, weight: .bold))
                                        .frame(width: 20, alignment: .center)  // 🌟 電源アイコンを中心に20pxの枠で揃える

                                    Text("Shutdown")
                                        .foregroundColor(theme.text)
                                }
                            }
                            .buttonStyle(.plain)

                            // reboot
                            Button(action: {
                                let _ = systemController.rebootSystem()
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .foregroundColor(theme.peach)
                                        .font(.system(size: 14, weight: .bold))
                                        .frame(width: 20, alignment: .center)  // 🌟 他もすべて20pxの枠に収めて中央揃え

                                    Text("Reboot")
                                        .foregroundColor(theme.text)
                                }
                            }
                            .buttonStyle(.plain)

                            // logout
                            Button(action: {
                                let _ = systemController.logoutSystem()
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .foregroundColor(theme.blue)
                                        .font(.system(size: 14, weight: .bold))
                                        .frame(width: 20, alignment: .center)  // 🌟 ここが横長なので広めの20px枠が必要

                                    Text("Logout")
                                        .foregroundColor(theme.text)
                                }
                            }
                            .buttonStyle(.plain)

                            // screen lock
                            Button(action: {
                                let _ = systemController.lockScreen()
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "lock")
                                        .foregroundColor(theme.pink)  // ユーザーが追加したテーマ色を維持
                                        .font(.system(size: 14, weight: .bold))
                                        .frame(width: 20, alignment: .center)

                                    Text("Screen Lock")
                                        .foregroundColor(theme.text)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        // 🌟 左側のパディングをSmoothUIModule（ホームボタン側）のパディングと完全に同じ値にすることで縦軸を揃える！
                        .padding(.leading, compactMode ? 8 : 12)
                        .padding(.trailing, 16)
                        .padding(.vertical, 12)
                        .background(theme.base)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(theme.surface1, lineWidth: 1)
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
}
