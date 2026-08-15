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

    // Parameters to correct font misalignment (baseline and position) specific to Nerd Fonts
    public let xOffset: CGFloat
    public let yOffset: CGFloat

    /// Component that displays a Nerd Font icon
    /// - Parameters:
    ///   - type: Type of icon to display
    ///   - size: Font size of the icon and size of the reserved frame (default: 16)
    ///   - xOffset: Fine-tuning along the X axis (default: 0)
    ///   - yOffset: Fine-tuning along the Y axis (default: 0)
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
        // Read value from TOML. If undefined, display "?" for easier debugging
        let displayIcon = NerdFontManager.shared.icon(for: keyName) ?? "?"

        Text(displayIcon)
            // Allow font type to be changed depending on the environment
            // In many environments, fonts like `Symbols Nerd Font` are used, so specify the font name as needed
            // If Nerd Font is not installed on the system, system font is used as a fallback
            .font(.custom("JetBrainsMono Nerd Font Mono", size: size))
            .lineLimit(1)
            .minimumScaleFactor(1.0)
            // Use a fixed frame size to prevent layout breakage due to text baselines and line spacing margins
            .frame(width: size, height: size, alignment: .center)
            // Fine-tune position
            .offset(x: xOffset, y: yOffset)
            // Fix size to prevent affecting layout calculations of other UI elements
            .fixedSize()
    }
}
