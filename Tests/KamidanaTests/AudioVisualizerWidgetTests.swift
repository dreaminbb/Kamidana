import XCTest

@testable import KamidanaApp

final class AudioVisualizerWidgetTests: XCTestCase {
    func testLevelModelDownmixesStereoSamplesInMonoMode() {
        let buffer = AudioVisualizerPCMBuffer(
            samples: [
                1, -1,
                1, -1,
                1, -1,
                1, -1,
                1, -1,
            ],
            sampleRate: 48_000,
            channelCount: 2
        )

        XCTAssertEqual(
            AudioVisualizerWidgetModel.normalizedLevels(
                from: buffer,
                channelMode: .stereo,
                barCount: 5
            ),
            [1, 1, 1, 1, 1]
        )
        XCTAssertEqual(
            AudioVisualizerWidgetModel.normalizedLevels(
                from: buffer,
                channelMode: .mono,
                barCount: 5
            ),
            [0, 0, 0, 0, 0]
        )
    }

    func testLevelModelAcceptsNativeMonoBuffers() {
        let buffer = AudioVisualizerPCMBuffer(
            samples: [1, 1, 1, 1, 1],
            sampleRate: 48_000,
            channelCount: 1
        )

        XCTAssertEqual(
            AudioVisualizerWidgetModel.normalizedLevels(
                from: buffer,
                channelMode: .mono,
                barCount: 5
            ),
            [1, 1, 1, 1, 1]
        )
    }

    func testLevelModelReturnsStableEmptyLevelsForInvalidInput() {
        let buffer = AudioVisualizerPCMBuffer(
            samples: [],
            sampleRate: 48_000,
            channelCount: 2
        )

        XCTAssertEqual(
            AudioVisualizerWidgetModel.normalizedLevels(
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
}
