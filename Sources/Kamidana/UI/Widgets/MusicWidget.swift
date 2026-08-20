import AppKit
import SwiftUI

enum MusicFormatPart: Equatable {
  case text(String)
  case artwork
  case slider
}

enum MusicFormatParser {
  private static let componentTokens: [(token: String, part: MusicFormatPart)] = [
    ("{artwork}", .artwork),
    ("{slider}", .slider),
  ]

  static func parts(in format: String) -> [MusicFormatPart] {
    var remaining = format[...]
    var parts: [MusicFormatPart] = []

    while !remaining.isEmpty {
      let nextToken = componentTokens.compactMap { component -> (String.Index, String.Index, MusicFormatPart)? in
        guard let range = remaining.range(of: component.token) else { return nil }
        return (range.lowerBound, range.upperBound, component.part)
      }
      .min { $0.0 < $1.0 }

      guard let nextToken else {
        parts.append(.text(String(remaining)))
        break
      }

      if remaining.startIndex < nextToken.0 {
        parts.append(.text(String(remaining[..<nextToken.0])))
      }
      parts.append(nextToken.2)
      remaining = remaining[nextToken.1...]
    }

    return parts
  }
}

struct MusicWidget: View {
  @EnvironmentObject private var musicManager: MusicPlayingManager
  @Environment(\.kamidanaWidgetActivation) private var widgetActivation
  @Environment(\.kamidanaWidgetFormat) private var widgetFormat
  @Environment(\.kamidanaPopupStyle) private var popupStyle
  @Environment(\.kamidanaWidgetMotion) private var motion

  @State private var isActionPresented = false
  @State private var pendingCloseID: UUID?

  let config: MusicWidgetConfig

  var body: some View {
    if config.placement == .center {
      centerActionContent
    } else {
      standaloneContent
    }
  }

  @ViewBuilder
  private var standaloneContent: some View {
    ZStack {
      Button(action: presentAction) {
        MusicNormalContent(
          config: config,
          format: widgetFormat ?? config.normalFormat,
          artworkSize: 22
        )
      }
      .buttonStyle(WidgetButtonStyle())
      .onHover(perform: handleHover)
      .opacity(isActionPresented ? 0 : 1)
      .allowsHitTesting(!isActionPresented)
    }
    .overlay(alignment: actionAlignment) {
      if isActionPresented {
        MusicFormatView(
          format: config.formatOnAction,
          config: config,
          artworkSize: 28,
          sliderLayout: .compact,
          artworkSpinDuration: config.actionArtworkSpinDuration
        )
        .fixedSize(horizontal: true, vertical: false)
        .environment(\.kamidanaV1Style, popupStyle)
        .SmoothUIModule()
        .transition(actionTransition)
        .onHover(perform: handleHover)
        .zIndex(1)
      }
    }
    .zIndex(isActionPresented ? 100 : 0)
    .onReceive(
      NSWorkspace.shared.notificationCenter.publisher(
        for: NSWorkspace.didActivateApplicationNotification
      )
    ) { notification in
      if let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
        as? NSRunningApplication,
        application.bundleIdentifier == Bundle.main.bundleIdentifier
      {
        return
      }
      isActionPresented = false
    }
  }

  @ViewBuilder
  private var centerActionContent: some View {
    if musicManager.title.isEmpty {
      MusicNormalContent(
        config: config,
        format: config.normalFormat,
        artworkSize: 48
      )
      .font(.system(size: 18, weight: .semibold, design: .monospaced))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      VStack(spacing: 22) {
        if let metadataFormat = config.actionMetadataFormat {
          MusicFormatView(
            format: metadataFormat,
            config: config,
            artworkSize: 34,
            sliderLayout: .compact,
            artworkSpinDuration: config.actionArtworkSpinDuration
          )
          .font(.system(size: 20, weight: .bold, design: .rounded))
        }

        MusicFormatView(
          format: config.formatOnAction,
          config: config,
          artworkSize: 150,
          sliderLayout: .center,
          artworkSpinDuration: config.actionArtworkSpinDuration
        )
      }
      .padding(.horizontal, 36)
      .padding(.vertical, 20)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private var activation: KamidanaActivation {
    widgetActivation ?? .hover
  }

  private var actionTransition: AnyTransition {
    guard motion == .dynamic else { return .identity }
    let edge: Edge = config.extend == .right ? .leading : .trailing
    return .move(edge: edge).combined(with: .opacity)
  }

  private var actionAlignment: Alignment {
    config.extend == .right ? .leading : .trailing
  }

  private func presentAction() {
    guard activation == .click else { return }
    updateActionPresentation(true)
  }

  private func updateActionPresentation(_ isPresented: Bool) {
    if motion == .dynamic {
      withAnimation(.easeInOut(duration: 0.2)) {
        isActionPresented = isPresented
      }
    } else {
      var transaction = Transaction()
      transaction.disablesAnimations = true
      withTransaction(transaction) {
        isActionPresented = isPresented
      }
    }
  }

  private func closeAction() {
    updateActionPresentation(false)
  }

  private func presentHoveredAction() {
    guard activation == .hover else { return }
    updateActionPresentation(true)
  }

  private func handleHover(_ isHovered: Bool) {
    if isHovered {
      pendingCloseID = nil
      presentHoveredAction()
      return
    }

    let closeID = UUID()
    pendingCloseID = closeID
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
      guard pendingCloseID == closeID else { return }
      closeAction()
    }
  }
}

struct MusicNormalContent: View {
  let config: MusicWidgetConfig
  let format: String
  let artworkSize: CGFloat

  var body: some View {
    MusicFormatView(
      format: format,
      config: config,
      artworkSize: artworkSize,
      sliderLayout: .compact,
      artworkSpinDuration: config.artworkSpinDuration
    )
    .lineLimit(1)
  }
}

private enum MusicSliderLayout {
  case compact
  case center
}

private struct MusicFormatView: View {
  @EnvironmentObject private var musicManager: MusicPlayingManager
  @Environment(\.kamidanaV1Style) private var v1Style

  let format: String
  let config: MusicWidgetConfig
  let artworkSize: CGFloat
  let sliderLayout: MusicSliderLayout
  let artworkSpinDuration: Double

  var body: some View {
    let parts = MusicFormatParser.parts(in: format)
    HStack(spacing: 0) {
      ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
        switch part {
        case .text(let value):
          FormattedWidgetLabel(
            format: value,
            values: formatValues,
            iconColor: Color(hex: v1Style?.iconColor ?? config.defaultIconColor),
            textColor: Color(hex: v1Style?.color ?? colors.textPrimary),
            iconSize: sliderLayout == .center ? 22 : 20
          )
        case .artwork:
          MusicArtworkView(
            config: config,
            size: artworkSize,
            artworkSpinDuration: artworkSpinDuration
          )
        case .slider:
          MusicPlaybackControls(config: config, layout: sliderLayout)
        }
      }
    }
  }

  private var colors: GlobalColorsConfig {
    ConfigManager.shared.currentConfig.colors
  }

  private var formatValues: [String: String] {
    [
      "icon": config.defaultIcon,
      "title": musicManager.title.isEmpty ? "Not Playing" : musicManager.title,
      "artist": musicManager.artist,
      "album": musicManager.album,
    ]
  }
}

private struct MusicArtworkView: View {
  @EnvironmentObject private var musicManager: MusicPlayingManager

  let config: MusicWidgetConfig
  let size: CGFloat
  let artworkSpinDuration: Double

  var body: some View {
    TimelineView(
      .animation(
        minimumInterval: 1.0 / 30.0,
        paused: artworkSpinDuration <= 0 || !musicManager.isPlaying
      )
    ) { context in
      artwork
        .rotationEffect(.degrees(rotation(at: context.date)))
    }
  }

  private var artwork: some View {
    Group {
      if let artwork = musicManager.artwork {
        Image(nsImage: artwork)
          .resizable()
          .aspectRatio(contentMode: .fill)
      } else {
        ZStack {
          Color(hex: colors.surface)
          NerdFontIcon(config.defaultIcon, size: max(14, size / 3))
            .foregroundColor(Color(hex: config.defaultIconColor))
        }
      }
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
    .overlay(
      Circle()
        .stroke(Color(hex: colors.surfaceBorder).opacity(0.6), lineWidth: size > 40 ? 2 : 1)
    )
  }

  private var colors: GlobalColorsConfig {
    ConfigManager.shared.currentConfig.colors
  }

  private func rotation(at date: Date) -> Double {
    guard artworkSpinDuration > 0, musicManager.isPlaying else { return 0 }
    let progress =
      date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: artworkSpinDuration)
      / artworkSpinDuration
    return progress * 360
  }
}

private struct MusicPlaybackControls: View {
  @EnvironmentObject private var musicManager: MusicPlayingManager

  @State private var isDraggingSlider = false
  @State private var sliderValue = 0.0
  @State private var dragID = UUID()

  let config: MusicWidgetConfig
  let layout: MusicSliderLayout

  var body: some View {
    if layout == .center {
      VStack(spacing: 18) {
        playbackButtons(iconSize: 30, spacing: 36)
        progressSlider(showsTime: true, width: 300)
      }
      .padding(.leading, 22)
    } else {
      HStack(spacing: 10) {
        playbackButtons(iconSize: 16, spacing: 10)
        progressSlider(showsTime: false, width: 120)
      }
    }
  }

  private var colors: GlobalColorsConfig {
    ConfigManager.shared.currentConfig.colors
  }

  private var changeColor: Color {
    Color(hex: config.sliderChangeColor ?? colors.textPrimary)
  }

  private var pauseColor: Color {
    Color(hex: config.sliderPauseColor ?? colors.success)
  }

  private var barColor: Color {
    Color(hex: config.sliderBarColor ?? colors.accent)
  }

  private var displayedPosition: Double {
    isDraggingSlider ? sliderValue : musicManager.currentPosition
  }

  private func playbackButtons(iconSize: CGFloat, spacing: CGFloat) -> some View {
    HStack(spacing: spacing) {
      Button(action: { musicManager.changeTrack(direction: .previous) }) {
        NerdFontIcon(config.backwardIcon, size: iconSize)
          .foregroundColor(changeColor)
      }
      .buttonStyle(.plain)

      Button(action: { musicManager.pauseMusic() }) {
        NerdFontIcon(
          musicManager.isPlaying ? config.pauseIcon : config.playIcon,
          size: iconSize
        )
        .foregroundColor(pauseColor)
      }
      .buttonStyle(.plain)

      Button(action: { musicManager.changeTrack(direction: .next) }) {
        NerdFontIcon(config.forwardIcon, size: iconSize)
          .foregroundColor(changeColor)
      }
      .buttonStyle(.plain)
    }
  }

  private func progressSlider(showsTime: Bool, width: CGFloat) -> some View {
    HStack(spacing: 8) {
      if showsTime {
        timeLabel(displayedPosition, alignment: .leading)
      }

      Slider(
        value: Binding(
          get: { displayedPosition },
          set: { sliderValue = $0 }
        ),
        in: 0...max(musicManager.trackTime, 1),
        onEditingChanged: updateSliderEditing
      )
      .frame(width: width)
      .tint(barColor)
      .disabled(musicManager.trackTime <= 0)

      if showsTime {
        timeLabel(musicManager.trackTime, alignment: .trailing)
      }
    }
  }

  private func timeLabel(_ seconds: Double, alignment: Alignment) -> some View {
    Text(formatTime(seconds))
      .font(.system(size: 12, design: .monospaced))
      .foregroundColor(Color(hex: colors.textSecondary))
      .frame(width: 42, alignment: alignment)
  }

  private func updateSliderEditing(_ isEditing: Bool) {
    if isEditing {
      isDraggingSlider = true
      sliderValue = musicManager.currentPosition
      dragID = UUID()
      return
    }

    musicManager.seek(to: sliderValue)
    let completedDragID = dragID
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      guard dragID == completedDragID else { return }
      isDraggingSlider = false
    }
  }

  private func formatTime(_ time: Double) -> String {
    guard time.isFinite, time >= 0 else { return "0:00" }
    let totalSeconds = Int(time)
    return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
  }
}
