import CoreAudio
import Foundation

public class AudioVolumeManager {
    
    private let deviceManager = AudioDeviceManager()
    
    public init() {}
    
    // MARK: - Get Volume & Mute
    
    public func outputVolume() -> AudioVolume {
        guard let deviceID = deviceManager.defaultOutputDeviceID() else {
            return AudioVolume(value: 0.0, muted: false)
        }
        return getVolumeInfo(deviceID: deviceID, scope: kAudioObjectPropertyScopeOutput)
    }
    
    public func inputVolume() -> AudioVolume {
        guard let deviceID = deviceManager.defaultInputDeviceID() else {
            return AudioVolume(value: 0.0, muted: false)
        }
        return getVolumeInfo(deviceID: deviceID, scope: kAudioObjectPropertyScopeInput)
    }
    
    private func getVolumeInfo(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> AudioVolume {
        let volResult: Result<Float32, AudioError> = AudioProperty.getProperty(
            objectID: deviceID,
            selector: kAudioDevicePropertyVolumeScalar,
            scope: scope,
            defaultValue: 0.0
        )
        let volume = (try? volResult.get()) ?? 0.0
        
        let muteResult: Result<UInt32, AudioError> = AudioProperty.getProperty(
            objectID: deviceID,
            selector: kAudioDevicePropertyMute,
            scope: scope,
            defaultValue: 0
        )
        let muted = (try? muteResult.get()) == 1
        
        return AudioVolume(value: volume, muted: muted)
    }
    
    // MARK: - Set Volume
    
    public func setOutputVolume(_ value: Float) {
        guard let deviceID = deviceManager.defaultOutputDeviceID() else { return }
        setVolume(deviceID: deviceID, scope: kAudioObjectPropertyScopeOutput, value: value)
    }
    
    public func setInputVolume(_ value: Float) {
        guard let deviceID = deviceManager.defaultInputDeviceID() else { return }
        setVolume(deviceID: deviceID, scope: kAudioObjectPropertyScopeInput, value: value)
    }
    
    private func setVolume(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope, value: Float32) {
        // Clamp volume to 0.0 - 1.0 range
        let clampedValue = max(0.0, min(1.0, value))
        _ = AudioProperty.setProperty(
            objectID: deviceID,
            selector: kAudioDevicePropertyVolumeScalar,
            scope: scope,
            value: clampedValue
        )
    }
    
    // MARK: - Set Mute
    
    public func setOutputMute(_ muted: Bool) {
        guard let deviceID = deviceManager.defaultOutputDeviceID() else { return }
        setMute(deviceID: deviceID, scope: kAudioObjectPropertyScopeOutput, muted: muted)
    }
    
    public func setInputMute(_ muted: Bool) {
        guard let deviceID = deviceManager.defaultInputDeviceID() else { return }
        setMute(deviceID: deviceID, scope: kAudioObjectPropertyScopeInput, muted: muted)
    }
    
    private func setMute(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope, muted: Bool) {
        let value: UInt32 = muted ? 1 : 0
        _ = AudioProperty.setProperty(
            objectID: deviceID,
            selector: kAudioDevicePropertyMute,
            scope: scope,
            value: value
        )
    }
}
