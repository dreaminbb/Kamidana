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
        
        // デフォルト出力デバイスの変更監視
        var defaultOutputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // デフォルト入力デバイスの変更監視
        var defaultInputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // 物理的なデバイスの接続・切断の監視（リストの更新）
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
        
        // 注: 音量の変更監視は、現在のデフォルトデバイスIDに対して登録する必要があります。
        // 音量やミュートが変わるたびに検知するには、デバイスが切り替わるたびにリスナーを付け直す必要がありますが、
        // 今回は簡略化のためTimerで定期更新するか、ViewModelで手動更新させます。
        // （完全な実装には AudioObjectAddPropertyListenerBlock を各デバイスの音量アドレスに登録します）
    }
    
    public func stop() {
        // リスナーの解除処理（省略可）
        isListening = false
    }
}
