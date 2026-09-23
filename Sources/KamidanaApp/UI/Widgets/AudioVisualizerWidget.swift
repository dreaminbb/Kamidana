import SwiftUI

public struct AudioVisualizerWidgetConfig: Codable, Hashable {
    public var format: String
    public var position: KamidanaSoundVisualizerPosition
    public var height: Int
    public var barWidth: Double
    public var padding: KamidanaInsets
    public var gradientSeparation: Int
    public var captureScope: KamidanaAudioVisualizerCaptureScope
    public var channelMode: KamidanaAudioVisualizerChannelMode
    public var smoothness: Double
    public var outlineColor: String?
    public var gradientColors: [String]
    public var separationLength: Int

    public init(
        format: String = "{display}",
        position: KamidanaSoundVisualizerPosition = .bottom,
        height: Int = 1,
        barWidth: Double = 10,
        padding: KamidanaInsets = KamidanaInsets(),
        gradientSeparation: Int = 1,
        captureScope: KamidanaAudioVisualizerCaptureScope = .system,
        channelMode: KamidanaAudioVisualizerChannelMode = .stereo,
        smoothness: Double = 0.5,
        outlineColor: String? = nil,
        gradientColors: [String] = [],
        separationLength: Int = 5
    ) {
        self.format = format
        self.position = position
        self.height = height
        self.barWidth = barWidth
        self.padding = padding
        self.gradientSeparation = gradientSeparation
        self.captureScope = captureScope
        self.channelMode = channelMode
        self.smoothness = smoothness
        self.outlineColor = outlineColor
        self.gradientColors = gradientColors
        self.separationLength = separationLength
    }

    private enum CodingKeys: String, CodingKey {
        case format, position, height, barWidth, padding
        case gradientSeparation
        case captureScope
        case channelMode
        case smoothness
        case outlineColor
        case gradientColors
        case separationLength
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            format: try container.decodeIfPresent(String.self, forKey: .format) ?? "{display}",
            position: try container.decodeIfPresent(
                KamidanaSoundVisualizerPosition.self, forKey: .position) ?? .bottom,
            height: try container.decodeIfPresent(Int.self, forKey: .height) ?? 1,
            barWidth: try container.decodeIfPresent(Double.self, forKey: .barWidth) ?? 10,
            padding: try container.decodeIfPresent(KamidanaInsets.self, forKey: .padding)
                ?? KamidanaInsets(),
            gradientSeparation: try container.decodeIfPresent(Int.self, forKey: .gradientSeparation)
                ?? 1,
            captureScope: try container.decodeIfPresent(
                KamidanaAudioVisualizerCaptureScope.self, forKey: .captureScope) ?? .system,
            channelMode: try container.decodeIfPresent(
                KamidanaAudioVisualizerChannelMode.self, forKey: .channelMode) ?? .stereo,
            smoothness: try container.decodeIfPresent(Double.self, forKey: .smoothness) ?? 0.5,
            outlineColor: try container.decodeIfPresent(String.self, forKey: .outlineColor),
            gradientColors: try container.decodeIfPresent([String].self, forKey: .gradientColors)
                ?? [],
            separationLength: try container.decodeIfPresent(Int.self, forKey: .separationLength)
                ?? 5
        )
    }

    public var resolvedBarCount: Int {
        min(30, max(1, separationLength))
    }

    public var resolvedBarHeight: Int {
        min(100, max(1, height))
    }
}

struct AudioVisualizerWidget: View {
    @Environment(\.kamidanaWidgetFormat) private var widgetFormat
    let config: AudioVisualizerWidgetConfig

    var body: some View {
        AudioVisualizerDisplay(
            config: config,
            formatOverride: widgetFormat,
            showsSurface: true
        )
    }
}

struct AudioVisualizerDisplay: View {
    @Environment(\.theme) private var theme
    @StateObject private var model: AudioVisualizerWidgetModel

    let config: AudioVisualizerWidgetConfig
    let formatOverride: String?
    let showsSurface: Bool
    let visualizerPosition: KamidanaSoundVisualizerPosition?

    init(
        config: AudioVisualizerWidgetConfig,
        formatOverride: String? = nil,
        showsSurface: Bool = false,
        visualizerPosition: KamidanaSoundVisualizerPosition? = nil
    ) {
        self.config = config
        self.formatOverride = formatOverride
        self.showsSurface = showsSurface
        self.visualizerPosition = visualizerPosition
        _model = StateObject(wrappedValue: AudioVisualizerWidgetModel(config: config))
    }

    var body: some View {
        visualizerContent
            .onAppear { model.startListening() }
            .onDisappear { model.stopListening() }
    }

    @ViewBuilder
    private var visualizerContent: some View {
        if showsSurface {
            visualizerLayout
                .padding(visualizerPadding)
                .SmoothUIModule(theme: theme)
        } else {
            visualizerLayout
                .padding(visualizerPadding)
        }
    }

    private var visualizerPadding: EdgeInsets {
        EdgeInsets(
            top: CGFloat(config.padding.top),
            leading: CGFloat(config.padding.leading),
            bottom: CGFloat(config.padding.bottom),
            trailing: CGFloat(config.padding.trailing)
        )
    }

    private var horizontalVisualizer: some View {
        let components = formatComponents
        return HStack(spacing: 0) {
            Text(components.prefix)
                .foregroundColor(theme?.foreground)

            barCanvas(isVertical: false)

            Text(components.suffix)
                .foregroundColor(theme?.foreground)
        }
        .font(.system(size: 15, weight: .semibold, design: .monospaced))
        .fixedSize(horizontal: true, vertical: false)
    }

    private var verticalVisualizer: some View {
        let components = formatComponents
        return VStack(spacing: 0) {
            Text(components.prefix)
                .foregroundColor(theme?.foreground)

            barCanvas(isVertical: true)

            Text(components.suffix)
                .foregroundColor(theme?.foreground)
        }
        .font(.system(size: 15, weight: .semibold, design: .monospaced))
        .fixedSize(horizontal: false, vertical: true)
    }

    private func barCanvas(isVertical: Bool) -> some View {
        Canvas { context, size in
            drawBars(
                in: &context,
                size: size,
                isVertical: isVertical
            )
        }
        .frame(
            width: canvasSize(isVertical: isVertical).width,
            height: canvasSize(isVertical: isVertical).height
        )
        .fixedSize()
    }

    private var visualizerThickness: CGFloat {
        CGFloat(config.resolvedBarHeight) * 8
    }

    private var barWidth: CGFloat {
        min(100, max(1, CGFloat(config.barWidth)))
    }

    private var barGap: CGFloat { 1 }

    private func canvasSize(isVertical: Bool) -> CGSize {
        let barLength = CGFloat(model.levelsSnapshot.count) * (barWidth + barGap) - barGap
        return isVertical
            ? CGSize(width: visualizerThickness, height: barLength)
            : CGSize(width: barLength, height: visualizerThickness)
    }

    private func drawBars(
        in context: inout GraphicsContext,
        size: CGSize,
        isVertical: Bool
    ) {
        let levels = model.levelsSnapshot
        let outline = outlineColor

        for (index, level) in levels.enumerated() {
            let normalizedLevel = min(1, max(0, level * 2))
            let color = color(forBarAt: index)

            if isVertical {
                let y = CGFloat(index) * (barWidth + barGap)
                let width = normalizedLevel * size.width
                let x = visualizerPosition == .right ? size.width - width : 0
                let rect = CGRect(x: x, y: y, width: width, height: barWidth)
                drawBar(in: &context, rect: rect, color: color, outline: outline)
            } else {
                let x = CGFloat(index) * (barWidth + barGap)
                let height = normalizedLevel * size.height
                let rect = CGRect(
                    x: x,
                    y: size.height - height,
                    width: barWidth,
                    height: height
                )
                drawBar(in: &context, rect: rect, color: color, outline: outline)
            }
        }
    }

    private func drawBar(
        in context: inout GraphicsContext,
        rect: CGRect,
        color: Color,
        outline: Color?
    ) {
        let cornerRadius = min(2, min(rect.width, rect.height) / 2)
        let path = Path(roundedRect: rect, cornerRadius: cornerRadius)
        context.fill(path, with: .color(color))
        if let outline {
            context.stroke(path, with: .color(outline), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var visualizerLayout: some View {
        if visualizerPosition == .left || visualizerPosition == .right {
            verticalVisualizer
        } else {
            horizontalVisualizer
        }
    }

    private var formatComponents: (prefix: String, suffix: String) {
        let format = formatOverride ?? config.format
        guard let range = format.range(of: "{display}") else {
            return (format, "")
        }
        return (
            String(format[..<range.lowerBound]),
            String(format[range.upperBound...])
        )
    }

    private var outlineColor: Color? {
        guard let value = config.outlineColor, !value.isEmpty else { return nil }
        return Color(hex: value)
    }

    private func color(forBarAt index: Int) -> Color {
        guard !config.gradientColors.isEmpty else {
            return theme?.foreground ?? .primary
        }

        let colorCount = min(
            max(1, config.gradientSeparation),
            config.gradientColors.count
        )
        let colorIndex = min(
            colorCount - 1,
            index * colorCount / config.resolvedBarCount
        )
        return Color(hex: config.gradientColors[colorIndex])
    }
}

final class AudioVisualizerWidgetModel: ObservableObject {
    @Published private(set) var levels: [Double]

    private let config: AudioVisualizerWidgetConfig
    private let controller: AudioVisualizerController
    private let barCount: Int
    private var isListening = false

    init(
        config: AudioVisualizerWidgetConfig,
        controller: AudioVisualizerController? = nil
    ) {
        let barCount = config.resolvedBarCount
        self.config = config
        self.barCount = barCount
        self.levels = Array(repeating: 0, count: barCount)

        let captureScope: AudioVisualizerCaptureScope =
            config.captureScope == .system ? .system : .microphone
        let channelMode: AudioVisualizerChannelMode =
            config.channelMode == .stereo ? .stereo : .mono
        self.controller =
            controller
            ?? AudioVisualizerController(
                captureScope: captureScope,
                channelMode: channelMode
            )
    }

    var levelsSnapshot: [Double] {
        levels
    }

    func startListening() {
        guard !isListening else { return }

        controller.onAudioData = { [weak self] buffer in
            guard let self else { return }
            let newLevels = Self.normalizedLevels(
                from: buffer,
                channelMode: self.config.channelMode,
                barCount: self.barCount
            )
            DispatchQueue.main.async { [weak self] in
                self?.apply(newLevels)
            }
        }

        do {
            try controller.startListening()
            isListening = true
        } catch {
            isListening = false
        }
    }

    func stopListening() {
        guard isListening else { return }
        isListening = false
        controller.onAudioData = nil
        controller.stopListening()
    }

    static func normalizedLevels(
        from buffer: AudioVisualizerPCMBuffer,
        channelMode: KamidanaAudioVisualizerChannelMode,
        barCount: Int
    ) -> [Double] {
        guard buffer.channelCount > 0, buffer.frameCount > 0, barCount > 0 else {
            return Array(repeating: 0, count: max(0, barCount))
        }

        let selectedChannelCount = min(2, buffer.channelCount)

        return (0..<barCount).map { barIndex in
            let startFrame = barIndex * buffer.frameCount / barCount
            let endFrame = (barIndex + 1) * buffer.frameCount / barCount
            guard startFrame < endFrame else { return 0 }

            var squaredMagnitude = 0.0
            var sampleCount = 0
            for frame in startFrame..<endFrame {
                switch channelMode {
                case .stereo:
                    for channel in 0..<selectedChannelCount {
                        let sampleIndex = frame * buffer.channelCount + channel
                        guard buffer.samples.indices.contains(sampleIndex) else { continue }
                        let sample = Double(buffer.samples[sampleIndex])
                        squaredMagnitude += sample * sample
                        sampleCount += 1
                    }
                case .mono:
                    var mixedSample = 0.0
                    var mixedChannelCount = 0
                    for channel in 0..<selectedChannelCount {
                        let sampleIndex = frame * buffer.channelCount + channel
                        guard buffer.samples.indices.contains(sampleIndex) else { continue }
                        mixedSample += Double(buffer.samples[sampleIndex])
                        mixedChannelCount += 1
                    }
                    guard mixedChannelCount > 0 else { continue }
                    mixedSample /= Double(mixedChannelCount)
                    squaredMagnitude += mixedSample * mixedSample
                    sampleCount += 1
                }
            }

            guard sampleCount > 0 else { return 0 }
            let rootMeanSquare = sqrt(squaredMagnitude / Double(sampleCount))
            return min(1, sqrt(rootMeanSquare))
        }
    }

    private func apply(_ newLevels: [Double]) {
        let retainedWeight = min(0.95, max(0, config.smoothness) * 0.95)
        let incomingWeight = 1 - retainedWeight
        levels = zip(levels, newLevels).map { current, incoming in
            current * retainedWeight + incoming * incomingWeight
        }
    }

    deinit {
        controller.onAudioData = nil
        controller.stopListening()
    }
}
