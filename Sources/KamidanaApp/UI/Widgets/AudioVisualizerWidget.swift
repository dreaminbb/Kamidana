import Accelerate
import Foundation
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
    public var smoothness: AudioVisualizerSmoothness
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
        smoothness: AudioVisualizerSmoothness = .normal,
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
            smoothness: try container.decodeIfPresent(
                AudioVisualizerSmoothness.self, forKey: .smoothness) ?? .normal,
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
    let barHeightAtZeroSound: Float = 0.08
    let resolvedOutlineColor: Color?
    let resolvedGradientColors: [Color]

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
        self.resolvedOutlineColor = config.outlineColor.flatMap { value in
            value.isEmpty ? nil : Color(hex: value)
        }
        self.resolvedGradientColors = config.gradientColors.map { Color(hex: $0) }
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
            let normalizedLevel = CGFloat(
                min(1, max(self.barHeightAtZeroSound, level))
            )
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
        resolvedOutlineColor
    }

    private func color(forBarAt index: Int) -> Color {
        guard !resolvedGradientColors.isEmpty else {
            return theme?.foreground ?? .primary
        }

        let colorCount = min(
            max(1, config.gradientSeparation),
            resolvedGradientColors.count
        )
        let colorIndex = min(
            colorCount - 1,
            index * colorCount / config.resolvedBarCount
        )
        return resolvedGradientColors[colorIndex]
    }
}

internal final class AudioVisualizerAnalyzer {
    private static let fftSize = 512
    private static let silenceThreshold: Float = 0.000_01
    private static let minimumDecibels: Float = -72
    private static let levelBoostDecibels: Float = 1
    private static let frequencyContrastExponent: Float = 3
    private static let log2FFTSize = vDSP_Length(log2(Float(fftSize)))

    private final class Workspace {
        let spectrumSize: Int
        let packedSize: Int
        var input: [Float]
        var real: [Float]
        var imaginary : [Float]
        var magnitudes  :  [Float]
        var hannWindow : [Float]

        init() {

            self.spectrumSize = AudioVisualizerAnalyzer.fftSize / 2 + 1
            self.packedSize = AudioVisualizerAnalyzer.fftSize / 2
            self.input = [Float](repeating: 0, count: AudioVisualizerAnalyzer.fftSize)
            self.imaginary = [Float](repeating: 0, count: self.packedSize)
            self.real = [Float](repeating: 0, count: self.packedSize)
            self.magnitudes = [Float](repeating: 0, count: self.spectrumSize)
            self.hannWindow = [Float](repeating: 0, count: AudioVisualizerAnalyzer.fftSize)

            vDSP_hann_window(
                &hannWindow,
                vDSP_Length(AudioVisualizerAnalyzer.fftSize),
                Int32(vDSP_HANN_NORM)
            )
        }

        func clearInput() {
            vDSP_vclr(
                &input,
                1,
                vDSP_Length(AudioVisualizerAnalyzer.fftSize)
            )
        }

        func applyHannWindow() {
            input.withUnsafeMutableBufferPointer { inputBuffer in
                hannWindow.withUnsafeBufferPointer { windowBuffer in
                    guard
                        let inputPointer = inputBuffer.baseAddress,
                        let windowPointer = windowBuffer.baseAddress
                    else {
                        return
                    }
                    vDSP_vmul(
                        inputPointer,
                        1,
                        windowPointer,
                        1,
                        inputPointer,
                        1,
                        vDSP_Length(AudioVisualizerAnalyzer.fftSize)
                    )
                }
            }
        }

        func packRealFFTInput() {
            for index in 0..<packedSize {
                real[index] = input[index * 2]
                imaginary[index] = input[index * 2 + 1]
            }
        }
    }

    private let fftSetup: FFTSetup?
    private let workspace = Workspace()
    private var cachedSampleRate: Float?
    private var cachedBarCount = 0
    private var cachedBandRanges: [Range<Int>] = []

    init() {
        fftSetup = vDSP_create_fftsetup(
            Self.log2FFTSize,
            FFTRadix(kFFTRadix2)
        )
    }

    func normalizedLevels(
        from buffer: AudioVisualizerPCMBuffer,
        channelMode: AudioVisualizerChannelMode,
        barCount: Int
    ) -> [Float] {
        var levels = [Float](repeating: 0, count: max(0, barCount))
        guard
            buffer.channelCount > 0,
            buffer.frameCount > 0,
            buffer.sampleRate > 0,
            barCount > 0,
            fftSetup != nil
        else {
            return levels
        }

        let selectedChannelCount = min(2, buffer.channelCount)
        if channelMode == .mono {
            accumulateFrequencyLevels(
                from: buffer,
                channel: nil,
                weight: 1,
                into: &levels
            )
        } else {
            let channelWeight = 1 / Float(selectedChannelCount)
            for channel in 0..<selectedChannelCount {
                accumulateFrequencyLevels(
                    from: buffer,
                    channel: channel,
                    weight: channelWeight,
                    into: &levels
                )
            }
        }

        return levels
    }

    private func accumulateFrequencyLevels(
        from buffer: AudioVisualizerPCMBuffer,
        channel: Int?,
        weight: Float,
        into levels: inout [Float]
    ) {
        let copiedFrameCount = prepareInput(from: buffer, channel: channel)
        guard copiedFrameCount >= 2, let fftSetup else { return }

        removeDCOffset(sampleCount: copiedFrameCount)

        var peak: Float = 0
        workspace.input.withUnsafeBufferPointer { inputBuffer in
            guard let inputPointer = inputBuffer.baseAddress else { return }
            vDSP_maxmgv(
                inputPointer,
                1,
                &peak,
                vDSP_Length(copiedFrameCount)
            )
        }
        guard peak > Self.silenceThreshold else { return }

        workspace.applyHannWindow()
        workspace.packRealFFTInput()

        workspace.real.withUnsafeMutableBufferPointer { realBuffer in
            workspace.imaginary.withUnsafeMutableBufferPointer { imaginaryBuffer in
                guard
                    let realPointer = realBuffer.baseAddress,
                    let imaginaryPointer = imaginaryBuffer.baseAddress
                else {
                    return
                }

                var splitComplex = DSPSplitComplex(
                    realp: realPointer,
                    imagp: imaginaryPointer
                )
                vDSP_fft_zrip(
                    fftSetup,
                    &splitComplex,
                    1,
                    Self.log2FFTSize,
                    FFTDirection(FFT_FORWARD)
                )
            }
        }

        workspace.magnitudes[0] = abs(workspace.real[0])
        workspace.magnitudes[workspace.spectrumSize - 1] = abs(
            workspace.imaginary[0]
        )
        for index in 1..<(workspace.spectrumSize - 1) {
            let real = workspace.real[index]
            let imaginary = workspace.imaginary[index]
            workspace.magnitudes[index] = sqrt(
                real * real + imaginary * imaginary
            )
        }

        var spectralPeak: Float = 0
        workspace.magnitudes.withUnsafeBufferPointer { magnitudesBuffer in
            guard let magnitudesPointer = magnitudesBuffer.baseAddress else { return }
            vDSP_maxv(
                magnitudesPointer,
                1,
                &spectralPeak,
                vDSP_Length(workspace.spectrumSize)
            )
        }
        guard spectralPeak > 0 else { return }

        let bandRanges = frequencyBandRanges(
            sampleRate: buffer.sampleRate,
            barCount: levels.count
        )
        workspace.magnitudes.withUnsafeBufferPointer { magnitudesBuffer in
            guard let magnitudesPointer = magnitudesBuffer.baseAddress else { return }

            for (bandIndex, range) in bandRanges.enumerated() {
                var bandPeak: Float = 0
                vDSP_maxv(
                    magnitudesPointer.advanced(by: range.lowerBound),
                    1,
                    &bandPeak,
                    vDSP_Length(range.count)
                )
                let magnitudeRatio = max(
                    bandPeak / spectralPeak,
                    Float.leastNonzeroMagnitude
                )
                let decibels = 20 * log10(magnitudeRatio)
                let boostedDecibels = min(0, decibels + Self.levelBoostDecibels)
                let decibelLevel = min(
                    1,
                    max(
                        0,
                        (boostedDecibels - Self.minimumDecibels)
                            / -Self.minimumDecibels
                    )
                )
                let contrastedLevel = pow(
                    decibelLevel,
                    Self.frequencyContrastExponent
                )
                levels[bandIndex] += contrastedLevel * weight
            }
        }
    }

    private func prepareInput(
        from buffer: AudioVisualizerPCMBuffer,
        channel: Int?
    ) -> Int {
        workspace.clearInput()

        let copiedFrameCount = min(buffer.frameCount, Self.fftSize)
        let firstFrame = buffer.frameCount - copiedFrameCount
        let mixedChannelCount = min(2, buffer.channelCount)

        for destinationFrame in 0..<copiedFrameCount {
            let sourceFrame = firstFrame + destinationFrame
            let sourceIndex = sourceFrame * buffer.channelCount

            if let channel {
                workspace.input[destinationFrame] = buffer.samples[sourceIndex + channel]
            } else {
                var mixedSample: Float = 0
                for mixedChannel in 0..<mixedChannelCount {
                    mixedSample += buffer.samples[sourceIndex + mixedChannel]
                }
                workspace.input[destinationFrame] = mixedSample / Float(mixedChannelCount)
            }
        }

        return copiedFrameCount
    }

    private func removeDCOffset(sampleCount: Int) {
        var mean: Float = 0
        workspace.input.withUnsafeMutableBufferPointer { inputBuffer in
            guard let inputPointer = inputBuffer.baseAddress else { return }
            vDSP_meanv(
                inputPointer,
                1,
                &mean,
                vDSP_Length(sampleCount)
            )
            var negativeMean = -mean
            vDSP_vsadd(
                inputPointer,
                1,
                &negativeMean,
                inputPointer,
                1,
                vDSP_Length(sampleCount)
            )
        }
    }

    deinit {
        if let fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
        }
    }

    private func frequencyBandRanges(
        sampleRate: Float,
        barCount: Int
    ) -> [Range<Int>] {
        if cachedSampleRate == sampleRate,
            cachedBarCount == barCount,
            cachedBandRanges.count == barCount
        {
            return cachedBandRanges
        }

        let nyquist = sampleRate / 2
        let minimumFrequency = min(55, nyquist / 2)
        let maximumFrequency = min(20_000, nyquist)
        guard maximumFrequency > minimumFrequency else { return [] }

        let frequencyRatio = maximumFrequency / minimumFrequency
        var ranges: [Range<Int>] = []
        ranges.reserveCapacity(barCount)
        var previousUpperBin = 1

        for bandIndex in 0..<barCount {
            let lowerRatio = Float(bandIndex) / Float(barCount)
            let upperRatio = Float(bandIndex + 1) / Float(barCount)
            let lowerFrequency = minimumFrequency * pow(frequencyRatio, lowerRatio)
            let upperFrequency = minimumFrequency * pow(frequencyRatio, upperRatio)
            let calculatedLowerBin = Int(
                lowerFrequency / sampleRate * Float(Self.fftSize)
            )
            let lowerBin = min(
                workspace.spectrumSize - 1,
                max(previousUpperBin, calculatedLowerBin)
            )
            let upperBin = min(
                workspace.spectrumSize,
                max(
                    lowerBin + 1,
                    Int(ceil(upperFrequency / sampleRate * Float(Self.fftSize)))
                )
            )
            ranges.append(lowerBin..<upperBin)
            previousUpperBin = upperBin
        }

        cachedSampleRate = sampleRate
        cachedBarCount = barCount
        cachedBandRanges = ranges
        return ranges
    }
}

final class AudioVisualizerWidgetModel: ObservableObject {
    @Published private(set) var levels: [Float]

    private let config: AudioVisualizerWidgetConfig
    private let spectrumService: AudioVisualizerSpectrumProviding
    private let barCount: Int
    private var subscription: AudioVisualizerSpectrumSubscription?
    private var subscriptionGeneration = 0

    init(
        config: AudioVisualizerWidgetConfig,
        spectrumService: AudioVisualizerSpectrumProviding = AudioVisualizerSpectrumService.shared
    ) {
        let barCount = config.resolvedBarCount
        self.config = config
        self.spectrumService = spectrumService
        self.barCount = barCount
        self.levels = Array(repeating: 0, count: barCount)
    }

    var levelsSnapshot: [Float] {
        levels
    }

    func startListening() {
        guard subscription == nil else { return }

        subscriptionGeneration += 1
        let generation = subscriptionGeneration
        let configuration = AudioVisualizerSpectrumConfiguration(
            captureScope: config.captureScope == .system ? .system : .microphone,
            channelMode: config.channelMode == .stereo ? .stereo : .mono,
            bufferFrequency: config.smoothness.bufferFrequency
        )

        do {
            subscription = try spectrumService.subscribe(
                configuration: configuration,
                barCount: barCount
            ) { [weak self] newLevels in
                DispatchQueue.main.async { [weak self] in
                    guard
                        let self,
                        self.subscription != nil,
                        self.subscriptionGeneration == generation
                    else {
                        return
                    }
                    self.apply(newLevels)
                }
            }
        } catch {
            subscription = nil
        }
    }

    func stopListening() {
        subscriptionGeneration += 1
        subscription?.cancel()
        subscription = nil
    }

    private func apply(_ newLevels: [Float]) {
        let retainedWeight = Float(config.smoothness.retainedWeight)
        let incomingWeight = 1 - retainedWeight
        let smoothedLevels = zip(levels, newLevels).map { current, incoming in
            current * retainedWeight + incoming * incomingWeight
        }
        let hasVisibleChange = zip(levels, smoothedLevels).contains { current, updated in
            abs(current - updated) > 0.000_5
        }
        guard hasVisibleChange else { return }
        levels = smoothedLevels
    }

    deinit {
        subscription?.cancel()
    }
}
