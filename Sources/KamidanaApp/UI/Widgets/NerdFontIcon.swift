import SwiftUI

public struct NerdFontIcon: View {
  public let icon: String
  public let size: CGFloat

  // Parameters to correct font misalignment (baseline and position) specific to Nerd Fonts
  public let xOffset: CGFloat
  public let yOffset: CGFloat

  /// Component that displays a Nerd Font icon
  /// - Parameters:
  ///   - icon: String character of the icon to display
  ///   - size: Font size of the icon and size of the reserved frame (default: 20)
  ///   - xOffset: Fine-tuning along the X axis (default: 0)
  ///   - yOffset: Fine-tuning along the Y axis (default: 0)
  public init(
    _ icon: String, size: CGFloat = 20, xOffset: CGFloat = 0, yOffset: CGFloat = 0
  ) {
    self.icon = icon
    self.size = size
    self.xOffset = xOffset
    self.yOffset = yOffset
  }

  public var body: some View {
    Text(icon)
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
