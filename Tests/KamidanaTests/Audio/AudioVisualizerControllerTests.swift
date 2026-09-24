import Foundation
import XCTest

@testable import KamidanaApp

final class AudioVisualizerControllerTests: XCTestCase {
    func testAcceptsInjectedConfiguration() {
        let configuration = AudioVisualizerController.Configuration(
            captureScope: .microphone,
            channelMode: .mono,
            maxBufferedFrames: 256
        )
        let controller = AudioVisualizerController(configuration: configuration)

        XCTAssertEqual(controller.configuration, configuration)
    }

    func testForwardsCapturedPCMDataWhileListening() throws {
        let source = StubAudioVisualizerCaptureSource()
        let controller = AudioVisualizerController(captureSource: source)
        let expectedBuffer = AudioVisualizerPCMBuffer(
            samples: [0.25, -0.5, 0.75, -1.0],
            sampleRate: 48_000,
            channelCount: 2
        )
        var receivedBuffer: AudioVisualizerPCMBuffer?
        controller.onAudioData = { receivedBuffer = $0 }

        try controller.startListening()
        source.send(expectedBuffer)

        XCTAssertEqual(controller.state, .listening)
        XCTAssertEqual(source.startCount, 1)
        XCTAssertEqual(receivedBuffer, expectedBuffer)
        XCTAssertEqual(receivedBuffer?.frameCount, 2)
        XCTAssertEqual(receivedBuffer?.peakMagnitude, 1.0)
    }

    func testDoesNotForwardPCMDataAfterStopping() throws {
        let source = StubAudioVisualizerCaptureSource()
        let controller = AudioVisualizerController(captureSource: source)
        var receivedBufferCount = 0
        controller.onAudioData = { _ in receivedBufferCount += 1 }

        try controller.startListening()
        controller.stopListening()
        source.send(
            AudioVisualizerPCMBuffer(
                samples: [0.5, -0.5],
                sampleRate: 48_000,
                channelCount: 2
            )
        )

        XCTAssertEqual(controller.state, .stopped)
        XCTAssertEqual(source.stopCount, 1)
        XCTAssertEqual(receivedBufferCount, 0)
    }

    func testPublishesFailureAndStopsSourceWhenCaptureCannotStart() {
        let expectedError = AudioVisualizerError.coreAudio(
            operation: "AudioDeviceStart",
            status: -1
        )
        let source = StubAudioVisualizerCaptureSource(startError: expectedError)
        let controller = AudioVisualizerController(captureSource: source)
        var states: [AudioVisualizerController.State] = []
        controller.onStateChanged = { states.append($0) }

        XCTAssertThrowsError(try controller.startListening()) { error in
            XCTAssertEqual(error as? AudioVisualizerError, expectedError)
        }
        XCTAssertEqual(controller.state, .failed(expectedError))
        XCTAssertEqual(states, [.starting, .failed(expectedError)])
        XCTAssertEqual(source.stopCount, 1)
    }

    func testCapturesCurrentlyPlayingSystemAudio() throws {
        guard
            ProcessInfo.processInfo.environment["KAMIDANA_RUN_AUDIO_CAPTURE_INTEGRATION_TESTS"]
                == "1"
        else {
            throw XCTSkip(
                "Set KAMIDANA_RUN_AUDIO_CAPTURE_INTEGRATION_TESTS=1 and play audio to run this integration test."
            )
        }
        guard #available(macOS 14.2, *) else {
            throw XCTSkip("Core Audio Process Tap requires macOS 14.2 or later.")
        }

        let controller = AudioVisualizerController()
        let audioExpectation = expectation(description: "Receives non-silent system audio PCM data")
        controller.onAudioData = { buffer in
            if buffer.frameCount > 0 && buffer.peakMagnitude > 0.001 {
                audioExpectation.fulfill()
            }
        }

        try controller.startListening()
        defer { controller.stopListening() }

        wait(for: [audioExpectation], timeout: 10)
    }
}

private final class StubAudioVisualizerCaptureSource: AudioVisualizerCaptureSource {
    var onAudioData: ((AudioVisualizerPCMBuffer) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    private let startError: AudioVisualizerError?

    init(startError: AudioVisualizerError? = nil) {
        self.startError = startError
    }

    func start() throws {
        startCount += 1
        if let startError {
            throw startError
        }
    }

    func stop() {
        stopCount += 1
    }

    func send(_ buffer: AudioVisualizerPCMBuffer) {
        onAudioData?(buffer)
    }
}
