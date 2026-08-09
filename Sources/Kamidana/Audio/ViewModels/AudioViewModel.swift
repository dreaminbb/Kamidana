import Foundation
import Combine
import CoreAudio

public class AudioViewModel: ObservableObject {
    private let deviceManager = AudioDeviceManager()
    private let volumeManager = AudioVolumeManager()
    
    @Published public var outputVolume: Float = 0.0
    @Published public var isOutputMuted: Bool = false
    
    @Published public var inputVolume: Float = 0.0
    @Published public var isInputMuted: Bool = false
    
    @Published public var outputFormat: String = ""
    
    public init() {
        fetchInitialState()
    }
    
    public func fetchInitialState() {
        let outVol = volumeManager.outputVolume()
        self.outputVolume = outVol.value
        self.isOutputMuted = outVol.muted
        
        let inVol = volumeManager.inputVolume()
        self.inputVolume = inVol.value
        self.isInputMuted = inVol.muted
        
        if let outDeviceID = deviceManager.defaultOutputDeviceID(),
           let format = deviceManager.getPhysicalFormat(deviceID: outDeviceID, scope: kAudioObjectPropertyScopeOutput) {
            self.outputFormat = "\(format.bitDepth)bit \(format.formatName) \(Int(format.sampleRate))Hz"
        } else {
            self.outputFormat = "Unknown"
        }
    }
    
    public func setOutputVolume(_ value: Float) {
        self.outputVolume = value
        volumeManager.setOutputVolume(value)
    }
    
    public func toggleOutputMute() {
        self.isOutputMuted.toggle()
        volumeManager.setOutputMute(self.isOutputMuted)
    }
}
