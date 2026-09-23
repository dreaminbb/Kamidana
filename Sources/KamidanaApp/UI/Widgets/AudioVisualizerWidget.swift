import SwiftUI

public struct AudioVisualizerWidgetConfig: Codable, Hashable {
    public var format: String
    public var gradientSeparation: Int
    public var captureScope: KamidanaAudioVisualizerCaptureScope
    public var channelMode: KamidanaAudioVisualizerChannelMode
    public var smoothness: Double
    public var outlineColor: String?
    public var gradientColors: [String]
    public var separationLength: Int

    public init(
        format: String = "{display}",
        gradientSeparation: Int = 1,
        captureScope: KamidanaAudioVisualizerCaptureScope = .system,
        channelMode: KamidanaAudioVisualizerChannelMode = .stereo,
        smoothness: Double = 0.5,
        outlineColor: String? = nil,
        gradientColors: [String] = [],
        separationLength: Int = 5
    ) {
        self.format = format
        self.gradientSeparation = gradientSeparation
        self.captureScope = captureScope
        self.channelMode = channelMode
        self.smoothness = smoothness
        self.outlineColor = outlineColor
        self.gradientColors = gradientColors
        self.separationLength = separationLength
    }

    public var resolvedBarCount: Int {
        min(20, max(1, separationLength))
    }
}

struct AudioVisualizerWidget: View {
    @Environment(\.theme) private var theme
    @Environment(\.kamidanaWidgetFormat) private var widgetFormat
    @StateObject private var model: AudioVisualizerWidgetModel

    let config: AudioVisualizerWidgetConfig

    init(config: AudioVisualizerWidgetConfig) {
        self.config = config
        _model = StateObject(wrappedValue: AudioVisualizerWidgetModel(config: config))
    }

    var body: some View {
        let components = formatComponents

        HStack(spacing: 0) {
            Text(components.prefix)
                .foregroundColor(theme?.foreground)

            HStack(spacing: 1) {
                ForEach(Array(model.displayCharacters.enumerated()), id: \.offset) {
                    index, character in
                    Text(String(character))
                        .foregroundColor(color(forBarAt: index))
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .shadow(
                            color: outlineColor ?? .clear,
                            radius: outlineColor == nil ? 0 : 0.5
                        )
                }
            }

            Text(components.suffix)
                .foregroundColor(theme?.foreground)
        }
        .font(.system(size: 13, weight: .semibold, design: .monospaced))
        .fixedSize(horizontal: true, vertical: false)
        .SmoothUIModule(theme: theme)
        .onAppear { model.startListening() }
        .onDisappear { model.stopListening() }
    }

    private var formatComponents: (prefix: String, suffix: String) {
        let format = widgetFormat ?? config.format
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
    private static let levelCharacters: [Character] = Array("▁▂▃▄▅▆▇█")

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
        self.controller = controller ?? AudioVisualizerController(
            captureScope: captureScope,
            channelMode: channelMode
        )
    }

    var displayCharacters: [Character] {
        levels.map { level in
            let clampedLevel = min(1, max(0, level))
            let index = min(
                Self.levelCharacters.count - 1,
                Int((clampedLevel * Double(Self.levelCharacters.count - 1)).rounded())
            )
            return Self.levelCharacters[index]
        }
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
