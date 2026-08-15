import CoreAudio
import Foundation

public class AudioListener {
    
    public var onDeviceChanged: (() -> Void)?
    public var onVolumeChanged: (() -> Void)?
    
    private var isListening = false
    
    public init() {}
    
    public func start() {
        if isListening { return }
        isListening = true
        
        let systemObjectID = AudioObjectID(kAudioObjectSystemObject)
        
        // Monitor default output device changes
        var defaultOutputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Monitor default input device changes
        var defaultInputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Monitor physical device connection/disconnection (list updates)
        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectAddPropertyListenerBlock(systemObjectID, &defaultOutputAddress, DispatchQueue.main) { [weak self] _, _ in
            self?.onDeviceChanged?()
        }
        
        AudioObjectAddPropertyListenerBlock(systemObjectID, &defaultInputAddress, DispatchQueue.main) { [weak self] _, _ in
            self?.onDeviceChanged?()
        }
        
        AudioObjectAddPropertyListenerBlock(systemObjectID, &devicesAddress, DispatchQueue.main) { [weak self] _, _ in
            self?.onDeviceChanged?()
        }
        
        // Note: Volume change monitoring needs to be registered against the current default device ID.
        // Detecting volume/mute changes requires reattaching listeners whenever the device switches;
        // for simplicity, periodic updates via Timer or manual updates via ViewModel are used.
        // (For full implementation, register AudioObjectAddPropertyListenerBlock to each device's volume address)
    }
    
    public func stop() {
        // Listener cleanup (optional)
        isListening = false
    }
}
