import AVFoundation
import CoreAudio
import Foundation

public struct AudioVisualizerPCMBuffer: Equatable, Sendable {
    public let samples: [Float]
    public let sampleRate: Double
    public let channelCount: Int

    public init(samples: [Float], sampleRate: Double, channelCount: Int) {
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

public enum AudioVisualizerCaptureScope: Equatable, Sendable {
    case system
    case microphone
}

public enum AudioVisualizerChannelMode: Equatable, Sendable {
    case stereo
    case mono
}

public enum AudioVisualizerError: Error, Equatable, LocalizedError, Sendable {
    case unsupportedOperatingSystem
    case coreAudio(operation: String, status: OSStatus)
    case unexpected(message: String)
    case unsupportedStreamFormat(formatID: AudioFormatID, flags: AudioFormatFlags, bitsPerChannel: UInt32)

    public var errorDescription: String? {
        switch self {
        case .unsupportedOperatingSystem:
            return "System audio capture requires macOS 14.2 or later."
        case .coreAudio(let operation, let status):
            return "Core Audio operation \(operation) failed with status \(status)."
        case .unexpected(let message):
            return "Audio capture failed: \(message)"
        case .unsupportedStreamFormat(let formatID, let flags, let bitsPerChannel):
            return "Unsupported audio stream format: formatID=\(formatID), flags=\(flags), bitsPerChannel=\(bitsPerChannel)."
        }
    }
}

protocol AudioVisualizerCaptureSource: AnyObject {
    var onAudioData: ((AudioVisualizerPCMBuffer) -> Void)? { get set }

    func start() throws
    func stop()
}

public final class AudioVisualizerController {
    public enum State: Equatable, Sendable {
        case stopped
        case starting
        case listening
        case failed(AudioVisualizerError)
    }

    public var onAudioData: ((AudioVisualizerPCMBuffer) -> Void)?
    public var onStateChanged: ((State) -> Void)?

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
            captureSource: AudioVisualizerCaptureSourceFactory.make(
                captureScope: captureScope,
                channelMode: channelMode,
                maxBufferedFrames: maxBufferedFrames
            )
        )
    }

    init(captureSource: AudioVisualizerCaptureSource) {
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
        captureSource.stop()
    }
}

private enum AudioVisualizerCaptureSourceFactory {
    static func make(
        captureScope: AudioVisualizerCaptureScope,
        channelMode: AudioVisualizerChannelMode,
        maxBufferedFrames: Int
    ) -> AudioVisualizerCaptureSource {
        switch captureScope {
        case .system:
            if #available(macOS 14.2, *) {
                return CoreAudioProcessTapCaptureSource(
                    channelMode: channelMode,
                    maxBufferedFrames: maxBufferedFrames
                )
            }
            return UnavailableAudioVisualizerCaptureSource()
        case .microphone:
            return MicrophoneAudioCaptureSource(maxBufferedFrames: maxBufferedFrames)
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

    init(maxBufferedFrames: Int) {
        self.maxBufferedFrames = max(1, maxBufferedFrames)
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
            repeating: .milliseconds(16),
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
            let samples = sampleRingBuffer?.readAvailableSamples(),
            !samples.isEmpty
        else {
            return
        }

        onAudioData?(
            AudioVisualizerPCMBuffer(
                samples: samples,
                sampleRate: format.mSampleRate,
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

    init(
        channelMode: AudioVisualizerChannelMode,
        maxBufferedFrames: Int
    ) {
        self.channelMode = channelMode
        self.maxBufferedFrames = max(1, maxBufferedFrames)
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
            repeating: .milliseconds(16),
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
            let samples = sampleRingBuffer?.readAvailableSamples(),
            !samples.isEmpty
        else {
            return
        }

        onAudioData?(
            AudioVisualizerPCMBuffer(
                samples: samples,
                sampleRate: format.mSampleRate,
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

private final class AudioSampleRingBuffer {
    private let lock = NSLock()
    private let channelCount: Int
    private var storage: [Float]
    private var readIndex = 0
    private var writeIndex = 0
    private var sampleCount = 0

    init(capacity: Int, channelCount: Int) {
        self.channelCount = max(1, channelCount)
        storage = Array(repeating: 0, count: max(channelCount, capacity))
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

    func readAvailableSamples() -> [Float] {
        lock.lock()
        defer { lock.unlock() }

        let alignedSampleCount = sampleCount - (sampleCount % channelCount)
        guard alignedSampleCount > 0 else { return [] }

        var result = Array(repeating: Float.zero, count: alignedSampleCount)
        for index in result.indices {
            result[index] = storage[readIndex]
            readIndex = (readIndex + 1) % storage.count
        }
        sampleCount -= alignedSampleCount
        return result
    }

    private func writeInterleaved(_ buffer: AudioBuffer) {
        guard let data = buffer.mData else { return }

        let availableSamples = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
        let alignedSampleCount = availableSamples - (availableSamples % channelCount)
        let source = data.assumingMemoryBound(to: Float.self)

        for index in 0..<alignedSampleCount {
            append(source[index])
        }
    }

    private func writeNonInterleaved(_ buffers: UnsafeMutableAudioBufferListPointer) {
        let activeChannelCount = min(channelCount, buffers.count)
        guard activeChannelCount > 0 else { return }

        var frameCount = Int.max
        for channel in 0..<activeChannelCount {
            frameCount = min(
                frameCount,
                Int(buffers[channel].mDataByteSize) / MemoryLayout<Float>.size
            )
        }
        guard frameCount != Int.max, frameCount > 0 else { return }

        for frame in 0..<frameCount {
            for channel in 0..<activeChannelCount {
                guard let data = buffers[channel].mData else { return }
                append(data.assumingMemoryBound(to: Float.self)[frame])
            }
        }
    }

    private func append(_ sample: Float) {
        storage[writeIndex] = sample
        writeIndex = (writeIndex + 1) % storage.count

        if sampleCount == storage.count {
            readIndex = (readIndex + 1) % storage.count
        } else {
            sampleCount += 1
        }
    }
}
