import SwiftUI

public enum NerdFontIconType: String {
    case bluetooth = "\u{f00af}"
    case bluetoothSlash = "\u{f00b0}"
    case wifi = "\u{f0928}"
    case wifiSlash = "\u{f092f}"
    case network = "\u{f0318}"
    case battery = "\u{f240}"
    case batteryEmpty = "\u{f244}"
    case batteryQuarter = "\u{f243}"
    case batteryHalf = "\u{f242}"
    case batteryThreeQuarters = "\u{f241}"
    case batteryCharging = "\u{f0084}"
    case cpu = "\u{f4bc}"
    case memory = "\u{f035b}"
    case gpu = "\u{f08ae}"
    case disk = "\u{f02ca}"
    case arrowUpRight = "\u{f06f6}"
    case arrowDownRight = "\u{f06f4}"
    case arrowUpCircle = "\u{f01b}"
    case arrowDownCircle = "\u{f01a}"
    case clock = "\u{f0954}"
    case music = "\u{f001}"
    case play = "\u{f04b}"
    case pause = "\u{f04c}"
    case forward = "\u{f051}"
    case backward = "\u{f04a}"
    case speaker = "\u{f027}"
    case speakerWave = "\u{f028}"
    case mic = "\u{ec1c}"
    case micSlash = "\u{f131}"
    case appleLogo = "\u{f179}"
    case paperplane = "\u{f01d8}"
    case thermometer = "\u{f02cb}"
    case link = "\u{f0337}"
    case linkPlus = "\u{f0338}"
    case arrowClockwise = "\u{f002d}"
    case bolt = "\u{f00e7}"
    case grid = "\u{f00a}"
    case list = "\u{f03a}"
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
        let displayIcon = NerdFontManager.shared.icon(for: keyName) ?? type.rawValue

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
