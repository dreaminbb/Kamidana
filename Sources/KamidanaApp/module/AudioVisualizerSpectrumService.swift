import Foundation

struct AudioVisualizerSpectrumConfiguration: Hashable, Sendable {
    let captureScope: AudioVisualizerCaptureScope
    let channelMode: AudioVisualizerChannelMode
    let bufferFrequency: AudioVisualizerBufferFrequency
}

protocol AudioVisualizerAnalyzing: AnyObject {
    func normalizedLevels(
        from buffer: AudioVisualizerPCMBuffer,
        channelMode: AudioVisualizerChannelMode,
        barCount: Int
    ) -> [Float]
}

extension AudioVisualizerAnalyzer: AudioVisualizerAnalyzing {}

final class AudioVisualizerSpectrumSubscription {
    private let lock = NSLock()
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        lock.lock()
        let cancellation = cancellation
        self.cancellation = nil
        lock.unlock()
        cancellation?()
    }

    deinit {
        cancel()
    }
}

protocol AudioVisualizerSpectrumProviding: AnyObject {
    func subscribe(
        configuration: AudioVisualizerSpectrumConfiguration,
        barCount: Int,
        onLevels: @escaping ([Float]) -> Void
    ) throws -> AudioVisualizerSpectrumSubscription
}

final class AudioVisualizerSpectrumService: AudioVisualizerSpectrumProviding {
    typealias ControllerFactory =
        (AudioVisualizerSpectrumConfiguration) -> AudioVisualizerController
    typealias AnalyzerFactory = () -> AudioVisualizerAnalyzing

    static let shared = AudioVisualizerSpectrumService()

    private let lock = NSLock()
    private let controllerFactory: ControllerFactory
    private let analyzerFactory: AnalyzerFactory
    private var pipelines: [AudioVisualizerSpectrumConfiguration: AudioVisualizerSpectrumPipeline] = [:]

    init(
        controllerFactory: @escaping ControllerFactory = { configuration in
            AudioVisualizerController(
                configuration: AudioVisualizerController.Configuration(
                    captureScope: configuration.captureScope,
                    channelMode: configuration.channelMode,
                    bufferFrequency: configuration.bufferFrequency
                )
            )
        },
        analyzerFactory: @escaping AnalyzerFactory = { AudioVisualizerAnalyzer() }
    ) {
        self.controllerFactory = controllerFactory
        self.analyzerFactory = analyzerFactory
    }

    func subscribe(
        configuration: AudioVisualizerSpectrumConfiguration,
        barCount: Int,
        onLevels: @escaping ([Float]) -> Void
    ) throws -> AudioVisualizerSpectrumSubscription {
        lock.lock()
        defer { lock.unlock() }

        let pipeline: AudioVisualizerSpectrumPipeline
        if let existingPipeline = pipelines[configuration] {
            pipeline = existingPipeline
        } else {
            let newPipeline = AudioVisualizerSpectrumPipeline(
                configuration: configuration,
                controller: controllerFactory(configuration),
                analyzer: analyzerFactory()
            )
            pipelines[configuration] = newPipeline
            pipeline = newPipeline
        }

        do {
            let identifier = try pipeline.addSubscriber(
                barCount: max(1, barCount),
                onLevels: onLevels
            )
            return AudioVisualizerSpectrumSubscription { [weak self, weak pipeline] in
                guard let self, let pipeline else { return }
                self.unsubscribe(
                    identifier: identifier,
                    pipeline: pipeline,
                    configuration: configuration
                )
            }
        } catch {
            if pipeline.isEmpty {
                pipelines.removeValue(forKey: configuration)
            }
            throw error
        }
    }

    private func unsubscribe(
        identifier: UUID,
        pipeline: AudioVisualizerSpectrumPipeline,
        configuration: AudioVisualizerSpectrumConfiguration
    ) {
        lock.lock()
        defer { lock.unlock() }
        guard pipelines[configuration] === pipeline else { return }

        pipeline.removeSubscriber(identifier)
        if pipeline.isEmpty {
            pipelines.removeValue(forKey: configuration)
        }
    }
}

final class AudioVisualizerSpectrumPipeline {
    private struct Subscriber {
        let barCount: Int
        let onLevels: ([Float]) -> Void
    }

    private static let sharedBandCount = 30

    let configuration: AudioVisualizerSpectrumConfiguration

    private let controller: AudioVisualizerController
    private let analyzer: AudioVisualizerAnalyzing
    private let subscribersLock = NSLock()
    private var subscribers: [UUID: Subscriber] = [:]
    private var isStarted = false

    init(
        configuration: AudioVisualizerSpectrumConfiguration,
        controller: AudioVisualizerController,
        analyzer: AudioVisualizerAnalyzing
    ) {
        self.configuration = configuration
        self.controller = controller
        self.analyzer = analyzer
        controller.onAudioData = { [weak self] buffer in
            self?.process(buffer)
        }
    }

    var isEmpty: Bool {
        subscribersLock.lock()
        defer { subscribersLock.unlock() }
        return subscribers.isEmpty
    }

    func addSubscriber(
        barCount: Int,
        onLevels: @escaping ([Float]) -> Void
    ) throws -> UUID {
        let identifier = UUID()

        subscribersLock.lock()
        subscribers[identifier] = Subscriber(
            barCount: barCount,
            onLevels: onLevels
        )
        let shouldStart = !isStarted
        if shouldStart {
            isStarted = true
        }
        subscribersLock.unlock()

        if shouldStart {
            do {
                try controller.startListening()
            } catch {
                subscribersLock.lock()
                subscribers.removeValue(forKey: identifier)
                isStarted = false
                subscribersLock.unlock()
                throw error
            }
        }

        return identifier
    }

    func removeSubscriber(_ identifier: UUID) {
        subscribersLock.lock()
        subscribers.removeValue(forKey: identifier)
        let shouldStop = subscribers.isEmpty && isStarted
        if shouldStop {
            isStarted = false
        }
        subscribersLock.unlock()

        if shouldStop {
            controller.stopListening()
        }
    }

    private func process(_ buffer: AudioVisualizerPCMBuffer) {
        let sharedLevels = analyzer.normalizedLevels(
            from: buffer,
            channelMode: configuration.channelMode,
            barCount: Self.sharedBandCount
        )

        subscribersLock.lock()
        let currentSubscribers = Array(subscribers.values)
        subscribersLock.unlock()

        for subscriber in currentSubscribers {
            subscriber.onLevels(
                Self.resampledLevels(
                    sharedLevels,
                    targetCount: subscriber.barCount
                )
            )
        }
    }

    static func resampledLevels(
        _ sourceLevels: [Float],
        targetCount: Int
    ) -> [Float] {
        guard targetCount > 0, !sourceLevels.isEmpty else {
            return Array(repeating: 0, count: max(0, targetCount))
        }
        guard targetCount != sourceLevels.count else { return sourceLevels }

        return (0..<targetCount).map { targetIndex in
            let startIndex = targetIndex * sourceLevels.count / targetCount
            let endIndex = max(
                startIndex + 1,
                (targetIndex + 1) * sourceLevels.count / targetCount
            )
            return sourceLevels[startIndex..<min(endIndex, sourceLevels.count)].max() ?? 0
        }
    }
}
