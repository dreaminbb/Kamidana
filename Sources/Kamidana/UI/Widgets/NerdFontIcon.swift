import SwiftUI

public enum NerdFontIconType {
    case bluetooth
    case bluetoothSlash
    case wifi
    case wifiSlash
    case network
    case battery
    case batteryEmpty
    case batteryQuarter
    case batteryHalf
    case batteryThreeQuarters
    case batteryCharging
    case cpu
    case memory
    case gpu
    case disk
    case arrowUpRight
    case arrowDownRight
    case arrowUpCircle
    case arrowDownCircle
    case clock
    case music
    case play
    case pause
    case forward
    case backward
    case speaker
    case speakerWave
    case mic
    case micSlash
    case appleLogo
    case paperplane
    case thermometer
    case link
    case linkPlus
    case arrowClockwise
    case bolt
    case grid
    case list
    case bed
    case laptop
    case power
    case exit
    case lock
}

public struct NerdFontIcon: View {
    public let type: NerdFontIconType
    public let size: CGFloat

    // NerdFont特有のフォントのずれ（ベースラインや位置）を補正するパラメータ
    public let xOffset: CGFloat
    public let yOffset: CGFloat

    /// NerdFontアイコンを表示するコンポーネント
    /// - Parameters:
    ///   - type: 表示するアイコンの種類
    ///   - size: アイコンのフォントサイズおよび確保するフレームの大きさ (デフォルト: 16)
    ///   - xOffset: X軸の微調整 (デフォルト: 0)
    ///   - yOffset: Y軸の微調整 (デフォルト: 0)
    public init(
        _ type: NerdFontIconType, size: CGFloat = 16, xOffset: CGFloat = 0, yOffset: CGFloat = 0
    ) {
        self.type = type
        self.size = size
        self.xOffset = xOffset
        self.yOffset = yOffset
    }

    public var body: some View {
        let keyName = String(describing: type)
        // TOMLから値を読み込む。未定義の場合は"?"で表示してデバッグしやすくする
        let displayIcon = NerdFontManager.shared.icon(for: keyName) ?? "?"

        Text(displayIcon)
            // フォントの種類は環境に合わせて変更できるようにする
            // 多くの環境で `Symbols Nerd Font` 等が使われるため、必要に応じてフォント名を指定
            // もしNerd Fontがシステムにインストールされていない場合はシステムフォントがフォールバックされる
            .font(.custom("JetBrainsMono Nerd Font Mono", size: size))
            .lineLimit(1)
            .minimumScaleFactor(1.0)
            // テキストのベースラインや行間の余白によるレイアウトの崩れを防ぐため、フレームを固定サイズにする
            .frame(width: size, height: size, alignment: .center)
            // 位置の微調整
            .offset(x: xOffset, y: yOffset)
            // 他のUI要素のレイアウト計算に影響を与えないように固定サイズ化
            .fixedSize()
    }
}
