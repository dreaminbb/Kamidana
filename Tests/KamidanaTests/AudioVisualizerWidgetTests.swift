import XCTest

@testable import KamidanaApp

final class AudioVisualizerWidgetTests: XCTestCase {
    func testFrequencyLevelsDownmixOppositeChannelsToSilence() {
        let samples = (0..<2_048).flatMap { index in
            let sample = sin(2 * Double.pi * 1_000 * Double(index) / 48_000)
            return [Float(sample), Float(-sample)]
        }
        let buffer = AudioVisualizerPCMBuffer(
            samples: samples,
            sampleRate: 48_000,
            channelCount: 2
        )
        let analyzer = AudioVisualizerAnalyzer()

        let stereoLevels = analyzer.normalizedLevels(
            from: buffer,
            channelMode: .stereo,
            barCount: 5
        )
        XCTAssertGreaterThan(stereoLevels.max() ?? 0, 0.5)
        XCTAssertEqual(
            analyzer.normalizedLevels(
                from: buffer,
                channelMode: .mono,
                barCount: 5
            ),
            [0, 0, 0, 0, 0]
        )
    }

    func testFrequencyLevelsDistributeAnAudioToneIntoConfiguredBands() {
        let sampleRate: Float = 48_000
        let frequency: Float = 1_000
        let samples = (0..<2_048).map { index in
            sin(
                2 * Double.pi * Double(frequency) * Double(index)
                    / Double(sampleRate)
            )
        }
        let buffer = AudioVisualizerPCMBuffer(
            samples: samples.map(Float.init),
            sampleRate: sampleRate,
            channelCount: 1
        )
        let analyzer = AudioVisualizerAnalyzer()

        let levels = analyzer.normalizedLevels(
            from: buffer,
            channelMode: .mono,
            barCount: 12
        )

        XCTAssertEqual(levels.count, 12)
        XCTAssertGreaterThan(levels.max() ?? 0, 0.5)
        XCTAssertLessThan(levels.filter { $0 > 0.5 }.count, 4)
    }

    func testQuietAudioToneProducesVisibleLevels() {
        let sampleRate: Float = 48_000
        let frequency: Float = 1_000
        let samples = (0..<2_048).map { index in
            Float(
                sin(
                    2 * Double.pi * Double(frequency) * Double(index)
                        / Double(sampleRate)
                )
            ) * 0.001
        }
        let buffer = AudioVisualizerPCMBuffer(
            samples: samples,
            sampleRate: sampleRate,
            channelCount: 1
        )
        let analyzer = AudioVisualizerAnalyzer()

        let levels = analyzer.normalizedLevels(
            from: buffer,
            channelMode: .mono,
            barCount: 12
        )

        XCTAssertGreaterThan(levels.max() ?? 0, 0.4)
    }

    func testFrequencyLevelsAcceptNativeMonoBuffers() {
        let buffer = AudioVisualizerPCMBuffer(
            samples: [1, 1, 1, 1, 1],
            sampleRate: 48_000,
            channelCount: 1
        )
        let analyzer = AudioVisualizerAnalyzer()

        XCTAssertEqual(
            analyzer.normalizedLevels(
                from: buffer,
                channelMode: .mono,
                barCount: 5
            ),
            [0, 0, 0, 0, 0]
        )
    }

    func testLevelModelReturnsStableEmptyLevelsForInvalidInput() {
        let buffer = AudioVisualizerPCMBuffer(
            samples: [],
            sampleRate: 48_000,
            channelCount: 2
        )
        let analyzer = AudioVisualizerAnalyzer()

        XCTAssertEqual(
            analyzer.normalizedLevels(
                from: buffer,
                channelMode: .stereo,
                barCount: 5
            ),
            [0, 0, 0, 0, 0]
        )
    }

    func testWidgetRegistryContainsAudioVisualizerFactory() {
        WidgetRegistry.shared.registerAllWidgets()

        XCTAssertNotNil(WidgetRegistry.shared.factory(for: "audioVisualizer"))
    }

    func testConfigResolvesBarHeightUpToOneHundred() {
        XCTAssertEqual(AudioVisualizerWidgetConfig(height: 1).resolvedBarHeight, 1)
        XCTAssertEqual(AudioVisualizerWidgetConfig(height: 8).resolvedBarHeight, 8)
        XCTAssertEqual(AudioVisualizerWidgetConfig(height: 100).resolvedBarHeight, 100)
        XCTAssertEqual(AudioVisualizerWidgetConfig(height: 120).resolvedBarHeight, 100)
    }

    func testSmoothnessResolvesMatchingBufferFrequency() {
        XCTAssertEqual(AudioVisualizerSmoothness.high.bufferFrequency, .high)
        XCTAssertEqual(AudioVisualizerSmoothness.normal.bufferFrequency, .normal)
        XCTAssertEqual(AudioVisualizerSmoothness.low.bufferFrequency, .low)
        XCTAssertEqual(AudioVisualizerSmoothness.high.bufferFrequency.milliseconds, 16)
        XCTAssertEqual(AudioVisualizerSmoothness.normal.bufferFrequency.milliseconds, 30)
        XCTAssertEqual(AudioVisualizerSmoothness.low.bufferFrequency.milliseconds, 60)
    }
}
