import Foundation
import Combine
import CoreAudio

public class AudioViewModel: ObservableObject {
    private let deviceManager = AudioDeviceManager()
    private let volumeManager = AudioVolumeManager()
    private let listener = AudioListener()
    
    @Published public var outputVolume: Float = 0.0
    @Published public var isOutputMuted: Bool = false
    
    @Published public var inputVolume: Float = 0.0
    @Published public var isInputMuted: Bool = false
    
    @Published public var outputFormat: String = ""
    
    @Published public var outputDevices: [AudioDevice] = []
    @Published public var currentOutputDevice: AudioDevice?
    
    private var timer: AnyCancellable?
    
    public init() {
        fetchInitialState()
        
        listener.onDeviceChanged = { [weak self] in
            self?.fetchInitialState()
        }
        listener.start()
        
        // 音量変更の外部からの変更を検知するためのポーリング（より安全）
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchVolumeOnly()
            }
    }
    
    public func fetchInitialState() {
        self.outputDevices = deviceManager.outputDevices()
        self.currentOutputDevice = deviceManager.defaultOutput()
        
        fetchVolumeOnly()
        
        if let outDeviceID = deviceManager.defaultOutputDeviceID(),
           let format = deviceManager.getPhysicalFormat(deviceID: outDeviceID, scope: kAudioObjectPropertyScopeOutput) {
            self.outputFormat = "\(format.bitDepth)bit \(format.formatName) \(Int(format.sampleRate))Hz"
        } else {
            self.outputFormat = "Unknown"
        }
    }
    
    private func fetchVolumeOnly() {
        let outVol = volumeManager.outputVolume()
        if self.outputVolume != outVol.value { self.outputVolume = outVol.value }
        if self.isOutputMuted != outVol.muted { self.isOutputMuted = outVol.muted }
        
        let inVol = volumeManager.inputVolume()
        if self.inputVolume != inVol.value { self.inputVolume = inVol.value }
        if self.isInputMuted != inVol.muted { self.isInputMuted = inVol.muted }
    }
    
    public func setOutputVolume(_ value: Float) {
        self.outputVolume = value
        volumeManager.setOutputVolume(value)
    }
    
    public func toggleOutputMute() {
        self.isOutputMuted.toggle()
        volumeManager.setOutputMute(self.isOutputMuted)
    }
    
    public func changeOutputDevice(_ device: AudioDevice) {
        deviceManager.setOutput(device)
        // 変更直後に再取得
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.fetchInitialState()
        }
    }
}
