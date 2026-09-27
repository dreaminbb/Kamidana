import AVFoundation
import CoreAudio
import Foundation

public struct AudioVisualizerPCMBuffer: Equatable, Sendable {
    public let samples: [Float]
    public let sampleRate: Float
    public let channelCount: Int

    public init(samples: [Float], sampleRate: Float, channelCount: Int) {
        self.samples = samples
        self.sampleRate = sampleRate
        self.channelCount = channelCount
    }

    public var frameCount: Int {
        guard channelCount > 0 else { return 0 }
        return samples.count / channelCount
    }

    public var peakMagnitude: Float {
        samples.reduce(0) { max($0, abs($1)) }
    }
}

public enum AudioVisualizerCaptureScope: Equatable, Hashable, Sendable {
    case system
    case microphone
}

public enum AudioVisualizerChannelMode: Equatable, Hashable, Sendable {
    case stereo
    case mono
}

public enum AudioVisualizerBufferFrequency: String, Codable, Equatable, Hashable, Sendable {
    case high
    case normal
    case low

    public var milliseconds: Int {
        switch self {
        case .high: return 16
        case .normal: return 30
        case .low: return 60
        }
    }
}

public enum AudioVisualizerSmoothness: String, Codable, Equatable, Hashable, Sendable {
    case high
    case normal
    case low

    public var retainedWeight: Double {
        switch self {
        case .high: return 0.95
        case .normal: return 0.475
        case .low: return 0.0
        }
    }

    public var bufferFrequency: AudioVisualizerBufferFrequency {
        switch self {
        case .high: return .high
        case .normal: return .normal
        case .low: return .low
        }
    }
}

public enum AudioVisualizerError: Error, Equatable, LocalizedError, Sendable {
    case unsupportedOperatingSystem
    case coreAudio(operation: String, status: OSStatus)
    case unexpected(message: String)
    case unsupportedStreamFormat(
        formatID: AudioFormatID, flags: AudioFormatFlags, bitsPerChannel: UInt32)

    public var errorDescription: String? {
        switch self {
        case .unsupportedOperatingSystem:
            return "System audio capture requires macOS 14.2 or later."
        case .coreAudio(let operation, let status):
            return "Core Audio operation \(operation) failed with status \(status)."
        case .unexpected(let message):
            return "Audio capture failed: \(message)"
        case .unsupportedStreamFormat(let formatID, let flags, let bitsPerChannel):
            return
                "Unsupported audio stream format: formatID=\(formatID), flags=\(flags), bitsPerChannel=\(bitsPerChannel)."
        }
    }
}

protocol AudioVisualizerCaptureSource: AnyObject {
    var onAudioData: ((AudioVisualizerPCMBuffer) -> Void)? { get set }

    func start() throws
    func stop()
}

public final class AudioVisualizerController {
    public struct Configuration: Equatable, Sendable {
        public var captureScope: AudioVisualizerCaptureScope
        public var channelMode: AudioVisualizerChannelMode
        public var maxBufferedFrames: Int
        public var bufferFrequency: AudioVisualizerBufferFrequency

        public init(
            captureScope: AudioVisualizerCaptureScope = .system,
            channelMode: AudioVisualizerChannelMode = .stereo,
            maxBufferedFrames: Int = 16_384,
            bufferFrequency: AudioVisualizerBufferFrequency = .normal
        ) {
            self.captureScope = captureScope
            self.channelMode = channelMode
            self.maxBufferedFrames = max(1, maxBufferedFrames)
            self.bufferFrequency = bufferFrequency
        }
    }

    public enum State: Equatable, Sendable {
        case stopped
        case starting
        case listening
        case failed(AudioVisualizerError)
    }

    public var onAudioData: ((AudioVisualizerPCMBuffer) -> Void)?
    public var onStateChanged: ((State) -> Void)?
    public let configuration: Configuration

    public private(set) var state: State = .stopped {
        didSet {
            guard state != oldValue else { return }
            onStateChanged?(state)
        }
    }

    private let captureSource: AudioVisualizerCaptureSource

    public convenience init(
        captureScope: AudioVisualizerCaptureScope = .system,
        channelMode: AudioVisualizerChannelMode = .stereo,
        maxBufferedFrames: Int = 16_384
    ) {
        self.init(
            configuration: Configuration(
                captureScope: captureScope,
                channelMode: channelMode,
                maxBufferedFrames: maxBufferedFrames
            )
        )
    }

    public convenience init(configuration: Configuration) {
        self.init(
            captureSource: AudioVisualizerCaptureSourceFactory.make(
                captureScope: configuration.captureScope,
                channelMode: configuration.channelMode,
                maxBufferedFrames: configuration.maxBufferedFrames,
                bufferFrequency: configuration.bufferFrequency
            ),
            configuration: configuration
        )
    }

    init(
        captureSource: AudioVisualizerCaptureSource,
        configuration: Configuration = Configuration()
    ) {
        self.configuration = configuration
        self.captureSource = captureSource
        captureSource.onAudioData = { [weak self] buffer in
            guard self?.state == .listening else { return }
            self?.onAudioData?(buffer)
        }
    }

    public func startListening() throws {
        guard state != .starting, state != .listening else { return }

        state = .starting
        do {
            try captureSource.start()
            state = .listening
        } catch let error as AudioVisualizerError {
            captureSource.stop()
            state = .failed(error)
            DebugRichConsole.printAudioVisualizerFailure(error)
            throw error
        } catch {
            let captureError = AudioVisualizerError.unexpected(
                message: error.localizedDescription
            )
            captureSource.stop()
            state = .failed(captureError)
            DebugRichConsole.printAudioVisualizerFailure(error)
            throw captureError
        }
    }

    public func stopListening() {
        guard state != .stopped else { return }
        state = .stopped
        captureSource.stop()
    }

    deinit {
        captureSource.onAudioData = nil
        switch state {
        case .starting, .listening:
            captureSource.stop()
        case .stopped, .failed:
            break
        }
    }
}

private enum AudioVisualizerCaptureSourceFactory {
    static func make(
        captureScope: AudioVisualizerCaptureScope,
        channelMode: AudioVisualizerChannelMode,
        maxBufferedFrames: Int,
        bufferFrequency: AudioVisualizerBufferFrequency
    ) -> AudioVisualizerCaptureSource {
        switch captureScope {
        case .system:
            if #available(macOS 14.2, *) {
                return CoreAudioProcessTapCaptureSource(
                    channelMode: channelMode,
                    maxBufferedFrames: maxBufferedFrames,
                    bufferFrequency: bufferFrequency
                )
            }
            return UnavailableAudioVisualizerCaptureSource()
        case .microphone:
            return MicrophoneAudioCaptureSource(
                maxBufferedFrames: maxBufferedFrames, bufferFrequency: bufferFrequency)
        }
    }
}

private final class UnavailableAudioVisualizerCaptureSource: AudioVisualizerCaptureSource {
    var onAudioData: ((AudioVisualizerPCMBuffer) -> Void)?

    func start() throws {
        throw AudioVisualizerError.unsupportedOperatingSystem
    }

    func stop() {}
}

private final class MicrophoneAudioCaptureSource: AudioVisualizerCaptureSource {
    var onAudioData: ((AudioVisualizerPCMBuffer) -> Void)?

    private let maxBufferedFrames: Int
    private let audioEngine = AVAudioEngine()
    private let analysisQueue = DispatchQueue(
        label: "com.shin.Kamidana.audio-visualizer.microphone-analysis",
        qos: .userInitiated
    )

    private var streamFormat: AudioStreamBasicDescription?
    private var sampleRingBuffer: AudioSampleRingBuffer?
    private var drainTimer: DispatchSourceTimer?
    private var isTapInstalled = false
    private var isRunning = false
    private let bufferFrequency: AudioVisualizerBufferFrequency

    init(
        maxBufferedFrames: Int,
        bufferFrequency: AudioVisualizerBufferFrequency = .normal
    ) {
        self.maxBufferedFrames = max(1, maxBufferedFrames)
        self.bufferFrequency = bufferFrequency

    }

    func start() throws {
        guard !isRunning else { return }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        let streamDescription = format.streamDescription.pointee
        try validate(format: streamDescription)

        let channelCount = Int(streamDescription.mChannelsPerFrame)
        streamFormat = streamDescription
        sampleRingBuffer = AudioSampleRingBuffer(
            capacity: maxBufferedFrames * channelCount,
            channelCount: channelCount
        )

        inputNode.installTap(
            onBus: 0,
            bufferSize: 1_024,
            format: format
        ) { [weak self] buffer, _ in
            self?.receive(inputData: buffer.audioBufferList)
        }
        isTapInstalled = true

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRunning = true
            startDrainTimer()
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        stopDrainTimer()

        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        if isRunning {
            audioEngine.stop()
        }

        isRunning = false
        streamFormat = nil
        sampleRingBuffer = nil
    }

    deinit {
        stop()
    }

    private func receive(inputData: UnsafePointer<AudioBufferList>) {
        guard let streamFormat, let sampleRingBuffer else { return }
        sampleRingBuffer.write(inputData: inputData, format: streamFormat)
    }

    private func startDrainTimer() {
        let timer = DispatchSource.makeTimerSource(queue: analysisQueue)
        timer.schedule(
            deadline: .now(),
            repeating: .milliseconds(bufferFrequency.milliseconds),
            leeway: .milliseconds(2)
        )
        timer.setEventHandler { [weak self] in
            self?.publishAvailableSamples()
        }
        drainTimer = timer
        timer.resume()
    }

    private func stopDrainTimer() {
        drainTimer?.setEventHandler {}
        drainTimer?.cancel()
        drainTimer = nil
    }

    private func publishAvailableSamples() {
        guard
            let format = streamFormat,
            let samples = sampleRingBuffer?.readLatestFrames(maxFrameCount: 2_048),
            !samples.isEmpty
        else {
            return
        }

        onAudioData?(
            AudioVisualizerPCMBuffer(
                samples: samples,
                sampleRate: Float(format.mSampleRate),
                channelCount: Int(format.mChannelsPerFrame)
            )
        )
    }

    private func validate(format: AudioStreamBasicDescription) throws {
        let isLinearPCM = format.mFormatID == kAudioFormatLinearPCM
        let isFloat = format.mFormatFlags & kAudioFormatFlagIsFloat != 0
        let hasChannels = format.mChannelsPerFrame > 0

        guard isLinearPCM, isFloat, format.mBitsPerChannel == 32, hasChannels else {
            throw AudioVisualizerError.unsupportedStreamFormat(
                formatID: format.mFormatID,
                flags: format.mFormatFlags,
                bitsPerChannel: format.mBitsPerChannel
            )
        }
    }
}

@available(macOS 14.2, *)
private final class CoreAudioProcessTapCaptureSource: AudioVisualizerCaptureSource {
    var onAudioData: ((AudioVisualizerPCMBuffer) -> Void)?

    private static let deviceIOProc: AudioDeviceIOProc = {
        _, _, inputData, _, _, _, clientData in
        guard let clientData else { return noErr }

        let source = Unmanaged<CoreAudioProcessTapCaptureSource>
            .fromOpaque(clientData)
            .takeUnretainedValue()
        source.receive(inputData: inputData)
        return noErr
    }

    private let channelMode: AudioVisualizerChannelMode
    private let maxBufferedFrames: Int
    private let analysisQueue = DispatchQueue(
        label: "com.shin.Kamidana.audio-visualizer.analysis",
        qos: .userInitiated
    )

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var streamFormat: AudioStreamBasicDescription?
    private var sampleRingBuffer: AudioSampleRingBuffer?
    private var drainTimer: DispatchSourceTimer?
    private var isRunning = false
    private let bufferFrequency: AudioVisualizerBufferFrequency

    init(
        channelMode: AudioVisualizerChannelMode,
        maxBufferedFrames: Int,
        bufferFrequency: AudioVisualizerBufferFrequency
    ) {
        self.channelMode = channelMode
        self.maxBufferedFrames = max(1, maxBufferedFrames)
        self.bufferFrequency = bufferFrequency
    }

    func start() throws {
        guard !isRunning else { return }

        do {
            let tapDescription: CATapDescription
            switch channelMode {
            case .stereo:
                tapDescription = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
            case .mono:
                tapDescription = CATapDescription(monoGlobalTapButExcludeProcesses: [])
            }
            tapDescription.name = "Kamidana Audio Visualizer"
            tapDescription.isPrivate = true
            tapDescription.muteBehavior = .unmuted

            var newTapID = AudioObjectID(kAudioObjectUnknown)
            try checkStatus(
                AudioHardwareCreateProcessTap(tapDescription, &newTapID),
                operation: "AudioHardwareCreateProcessTap"
            )
            tapID = newTapID

            let tapUID = tapDescription.uuid.uuidString
            let aggregateUID = "com.shin.Kamidana.audio-visualizer.\(UUID().uuidString)"
            let tapEntry: [String: Any] = [
                kAudioSubTapUIDKey: tapUID,
                kAudioSubTapDriftCompensationKey: false,
            ]
            let aggregateDescription: [String: Any] = [
                kAudioAggregateDeviceUIDKey: aggregateUID,
                kAudioAggregateDeviceNameKey: "Kamidana Audio Visualizer",
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceTapListKey: [tapEntry],
                kAudioAggregateDeviceTapAutoStartKey: true,
            ]

            var newAggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
            try checkStatus(
                AudioHardwareCreateAggregateDevice(
                    aggregateDescription as CFDictionary,
                    &newAggregateDeviceID
                ),
                operation: "AudioHardwareCreateAggregateDevice"
            )
            aggregateDeviceID = newAggregateDeviceID

            let format = try inputStreamFormat(deviceID: aggregateDeviceID)
            try validate(format: format)
            streamFormat = format

            let channelCount = Int(format.mChannelsPerFrame)
            sampleRingBuffer = AudioSampleRingBuffer(
                capacity: maxBufferedFrames * channelCount,
                channelCount: channelCount
            )

            var newIOProcID: AudioDeviceIOProcID?
            try checkStatus(
                AudioDeviceCreateIOProcID(
                    aggregateDeviceID,
                    Self.deviceIOProc,
                    Unmanaged.passUnretained(self).toOpaque(),
                    &newIOProcID
                ),
                operation: "AudioDeviceCreateIOProcID"
            )
            ioProcID = newIOProcID

            startDrainTimer()
            try checkStatus(
                AudioDeviceStart(aggregateDeviceID, ioProcID),
                operation: "AudioDeviceStart"
            )
            isRunning = true
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        stopDrainTimer()

        if aggregateDeviceID != kAudioObjectUnknown, let ioProcID {
            if isRunning {
                AudioDeviceStop(aggregateDeviceID, ioProcID)
            }
            AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID)
        }

        if aggregateDeviceID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
        }

        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
        }

        isRunning = false
        ioProcID = nil
        streamFormat = nil
        sampleRingBuffer = nil
        aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
    }

    fileprivate func receive(inputData: UnsafePointer<AudioBufferList>) {
        guard let streamFormat, let sampleRingBuffer else { return }
        sampleRingBuffer.write(inputData: inputData, format: streamFormat)
    }

    deinit {
        stop()
    }

    private func startDrainTimer() {
        let timer = DispatchSource.makeTimerSource(queue: analysisQueue)
        timer.schedule(
            deadline: .now(),
            repeating: .milliseconds(bufferFrequency.milliseconds),
            leeway: .milliseconds(2)
        )
        timer.setEventHandler { [weak self] in
            self?.publishAvailableSamples()
        }
        drainTimer = timer
        timer.resume()
    }

    private func stopDrainTimer() {
        drainTimer?.setEventHandler {}
        drainTimer?.cancel()
        drainTimer = nil
    }

    private func publishAvailableSamples() {
        guard
            let format = streamFormat,
            let samples = sampleRingBuffer?.readLatestFrames(maxFrameCount: 2_048),
            !samples.isEmpty
        else {
            return
        }

        onAudioData?(
            AudioVisualizerPCMBuffer(
                samples: samples,
                sampleRate: Float(format.mSampleRate),
                channelCount: Int(format.mChannelsPerFrame)
            )
        )
    }

    private func inputStreamFormat(deviceID: AudioObjectID) throws -> AudioStreamBasicDescription {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamFormat,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)

        try checkStatus(
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &format),
            operation: "AudioObjectGetPropertyData(stream format)"
        )
        return format
    }

    private func validate(format: AudioStreamBasicDescription) throws {
        let isLinearPCM = format.mFormatID == kAudioFormatLinearPCM
        let isFloat = format.mFormatFlags & kAudioFormatFlagIsFloat != 0
        let hasChannels = format.mChannelsPerFrame > 0

        guard isLinearPCM, isFloat, format.mBitsPerChannel == 32, hasChannels else {
            throw AudioVisualizerError.unsupportedStreamFormat(
                formatID: format.mFormatID,
                flags: format.mFormatFlags,
                bitsPerChannel: format.mBitsPerChannel
            )
        }
    }

    private func checkStatus(_ status: OSStatus, operation: String) throws {
        guard status == noErr else {
            throw AudioVisualizerError.coreAudio(operation: operation, status: status)
        }
    }
}

final class AudioSampleRingBuffer {
    private let lock = NSLock()
    private let channelCount: Int
    private var storage: [Float]
    private var readIndex = 0
    private var writeIndex = 0
    private var sampleCount = 0

    init(capacity: Int, channelCount: Int) {
        self.channelCount = max(1, channelCount)
        let minimumCapacity = max(self.channelCount, capacity)
        let alignedCapacity = minimumCapacity - (minimumCapacity % self.channelCount)
        storage = Array(repeating: 0, count: alignedCapacity)
    }

    func write(inputData: UnsafePointer<AudioBufferList>, format: AudioStreamBasicDescription) {
        guard lock.try() else { return }
        defer { lock.unlock() }

        let audioBuffers = UnsafeMutableAudioBufferListPointer(
            UnsafeMutablePointer(mutating: inputData)
        )
        let isNonInterleaved = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0

        if isNonInterleaved {
            writeNonInterleaved(audioBuffers)
        } else if let buffer = audioBuffers.first {
            writeInterleaved(buffer)
        }
    }

    func write(interleavedSamples samples: UnsafeBufferPointer<Float>) {
        guard lock.try() else { return }
        defer { lock.unlock() }
        writeInterleavedSamples(samples)
    }

    func readLatestFrames(maxFrameCount: Int) -> [Float] {
        guard maxFrameCount > 0 else { return [] }

        lock.lock()
        defer { lock.unlock() }

        let availableFrameCount = sampleCount / channelCount
        let frameCount = min(maxFrameCount, availableFrameCount)
        let resultSampleCount = frameCount * channelCount
        guard resultSampleCount > 0 else { return [] }

        let discardedSampleCount = sampleCount - resultSampleCount
        readIndex = advancedIndex(readIndex, by: discardedSampleCount)

        var result = Array(repeating: Float.zero, count: resultSampleCount)
        result.withUnsafeMutableBufferPointer { destination in
            storage.withUnsafeBufferPointer { source in
                guard
                    let sourceBaseAddress = source.baseAddress,
                    let destinationBaseAddress = destination.baseAddress
                else {
                    return
                }

                let firstSampleCount = min(resultSampleCount, storage.count - readIndex)
                destinationBaseAddress.update(
                    from: sourceBaseAddress.advanced(by: readIndex),
                    count: firstSampleCount
                )

                let secondSampleCount = resultSampleCount - firstSampleCount
                if secondSampleCount > 0 {
                    destinationBaseAddress.advanced(by: firstSampleCount).update(
                        from: sourceBaseAddress,
                        count: secondSampleCount
                    )
                }
            }
        }

        readIndex = advancedIndex(readIndex, by: resultSampleCount)
        sampleCount = 0
        return result
    }

    private func writeInterleaved(_ buffer: AudioBuffer) {
        guard let data = buffer.mData else { return }

        let availableSampleCount = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
        let source = UnsafeBufferPointer(
            start: data.assumingMemoryBound(to: Float.self),
            count: availableSampleCount
        )
        writeInterleavedSamples(source)
    }

    private func writeInterleavedSamples(_ samples: UnsafeBufferPointer<Float>) {
        let alignedSampleCount = samples.count - (samples.count % channelCount)
        let retainedSampleCount = min(alignedSampleCount, storage.count)
        guard retainedSampleCount > 0, let sourceBaseAddress = samples.baseAddress else { return }

        let sourceStartIndex = alignedSampleCount - retainedSampleCount
        let storageCapacity = storage.count
        prepareForWrite(sampleCount: retainedSampleCount)

        storage.withUnsafeMutableBufferPointer { destination in
            guard let destinationBaseAddress = destination.baseAddress else { return }

            let firstSampleCount = min(retainedSampleCount, storageCapacity - writeIndex)
            destinationBaseAddress.advanced(by: writeIndex).update(
                from: sourceBaseAddress.advanced(by: sourceStartIndex),
                count: firstSampleCount
            )

            let secondSampleCount = retainedSampleCount - firstSampleCount
            if secondSampleCount > 0 {
                destinationBaseAddress.update(
                    from: sourceBaseAddress.advanced(by: sourceStartIndex + firstSampleCount),
                    count: secondSampleCount
                )
            }
        }

        finishWrite(sampleCount: retainedSampleCount)
    }

    private func writeNonInterleaved(_ buffers: UnsafeMutableAudioBufferListPointer) {
        guard buffers.count >= channelCount else { return }

        var frameCount = Int.max
        for channel in 0..<channelCount {
            guard buffers[channel].mData != nil else { return }
            frameCount = min(
                frameCount,
                Int(buffers[channel].mDataByteSize) / MemoryLayout<Float>.size
            )
        }
        guard frameCount != Int.max, frameCount > 0 else { return }

        let retainedFrameCount = min(frameCount, storage.count / channelCount)
        let sourceFrameOffset = frameCount - retainedFrameCount
        let retainedSampleCount = retainedFrameCount * channelCount
        let destinationStartIndex = writeIndex
        prepareForWrite(sampleCount: retainedSampleCount)

        for channel in 0..<channelCount {
            guard let data = buffers[channel].mData else { return }
            let source = data.assumingMemoryBound(to: Float.self)
            var destinationIndex = destinationStartIndex + channel
            if destinationIndex >= storage.count {
                destinationIndex -= storage.count
            }

            for frame in 0..<retainedFrameCount {
                storage[destinationIndex] = source[sourceFrameOffset + frame]
                destinationIndex += channelCount
                if destinationIndex >= storage.count {
                    destinationIndex -= storage.count
                }
            }
        }

        finishWrite(sampleCount: retainedSampleCount)
    }

    private func prepareForWrite(sampleCount incomingSampleCount: Int) {
        let availableSampleCount = storage.count - sampleCount
        let discardedSampleCount = max(0, incomingSampleCount - availableSampleCount)
        readIndex = advancedIndex(readIndex, by: discardedSampleCount)
    }

    private func finishWrite(sampleCount writtenSampleCount: Int) {
        writeIndex = advancedIndex(writeIndex, by: writtenSampleCount)
        sampleCount = min(storage.count, sampleCount + writtenSampleCount)
    }

    private func advancedIndex(_ index: Int, by sampleCount: Int) -> Int {
        let advancedIndex = index + sampleCount
        return advancedIndex >= storage.count ? advancedIndex - storage.count : advancedIndex
    }
}
