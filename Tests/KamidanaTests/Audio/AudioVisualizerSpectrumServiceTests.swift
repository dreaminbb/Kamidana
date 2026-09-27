import XCTest

@testable import KamidanaApp

final class AudioVisualizerSpectrumServiceTests: XCTestCase {
    func testSharesOneAnalysisPipelineAcrossMatchingSubscribers() throws {
        let source = SpectrumServiceCaptureSourceStub()
        let analyzer = SpectrumServiceAnalyzerStub()
        var controllerCreationCount = 0
        var analyzerCreationCount = 0

        let service = AudioVisualizerSpectrumService(
            controllerFactory: { configuration in
                controllerCreationCount += 1
                return AudioVisualizerController(
                    captureSource: source,
                    configuration: AudioVisualizerController.Configuration(
                        captureScope: configuration.captureScope,
                        channelMode: configuration.channelMode,
                        bufferFrequency: configuration.bufferFrequency
                    )
                )
            },
            analyzerFactory: {
                analyzerCreationCount += 1
                return analyzer
            }
        )
        let configuration = AudioVisualizerSpectrumConfiguration(
            captureScope: .system,
            channelMode: .mono,
            bufferFrequency: .normal
        )
        var fiveBarLevels: [Float] = []
        var twelveBarLevels: [Float] = []

        let firstSubscription = try service.subscribe(
            configuration: configuration,
            barCount: 5
        ) { fiveBarLevels = $0 }
        let secondSubscription = try service.subscribe(
            configuration: configuration,
            barCount: 12
        ) { twelveBarLevels = $0 }

        source.send(
            AudioVisualizerPCMBuffer(
                samples: [0.25, -0.25, 0.5, -0.5],
                sampleRate: 48_000,
                channelCount: 1
            )
        )

        XCTAssertEqual(controllerCreationCount, 1)
        XCTAssertEqual(analyzerCreationCount, 1)
        XCTAssertEqual(source.startCount, 1)
        XCTAssertEqual(analyzer.analysisCount, 1)
        XCTAssertEqual(fiveBarLevels.count, 5)
        XCTAssertEqual(twelveBarLevels.count, 12)

        firstSubscription.cancel()
        XCTAssertEqual(source.stopCount, 0)
        secondSubscription.cancel()
        XCTAssertEqual(source.stopCount, 1)
    }

    func testSeparatesPipelinesForDifferentCaptureConfigurations() throws {
        var controllerCreationCount = 0
        let service = AudioVisualizerSpectrumService(
            controllerFactory: { configuration in
                controllerCreationCount += 1
                return AudioVisualizerController(
                    captureSource: SpectrumServiceCaptureSourceStub(),
                    configuration: AudioVisualizerController.Configuration(
                        captureScope: configuration.captureScope,
                        channelMode: configuration.channelMode,
                        bufferFrequency: configuration.bufferFrequency
                    )
                )
            },
            analyzerFactory: { SpectrumServiceAnalyzerStub() }
        )

        let systemSubscription = try service.subscribe(
            configuration: AudioVisualizerSpectrumConfiguration(
                captureScope: .system,
                channelMode: .mono,
                bufferFrequency: .normal
            ),
            barCount: 5,
            onLevels: { _ in }
        )
        let microphoneSubscription = try service.subscribe(
            configuration: AudioVisualizerSpectrumConfiguration(
                captureScope: .microphone,
                channelMode: .mono,
                bufferFrequency: .normal
            ),
            barCount: 5,
            onLevels: { _ in }
        )

        XCTAssertEqual(controllerCreationCount, 2)
        systemSubscription.cancel()
        microphoneSubscription.cancel()
    }

    func testResamplesSharedSpectrumForEachWidgetBarCount() {
        let sourceLevels = (0..<30).map(Float.init)

        let levels = AudioVisualizerSpectrumPipeline.resampledLevels(
            sourceLevels,
            targetCount: 5
        )

        XCTAssertEqual(levels, [5, 11, 17, 23, 29])
    }
}

private final class SpectrumServiceCaptureSourceStub: AudioVisualizerCaptureSource {
    var onAudioData: ((AudioVisualizerPCMBuffer) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start() throws {
        startCount += 1
    }

    func stop() {
        stopCount += 1
    }

    func send(_ buffer: AudioVisualizerPCMBuffer) {
        onAudioData?(buffer)
    }
}

private final class SpectrumServiceAnalyzerStub: AudioVisualizerAnalyzing {
    private(set) var analysisCount = 0

    func normalizedLevels(
        from buffer: AudioVisualizerPCMBuffer,
        channelMode: AudioVisualizerChannelMode,
        barCount: Int
    ) -> [Float] {
        analysisCount += 1
        return (0..<barCount).map { Float($0) / Float(max(1, barCount - 1)) }
    }
}
