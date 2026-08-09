import CoreAudio
import Foundation

public class AudioDeviceManager {
    
    public init() {}
    
    /// 接続されているすべてのオーディオデバイスのIDを取得します
    private func getDeviceIDs() -> [AudioDeviceID] {
        let result: Result<[AudioDeviceID], AudioError> = AudioProperty.getArrayProperty(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDevices
        )
        switch result {
        case .success(let ids): return ids
        case .failure: return []
        }
    }
    
    private func hasStreams(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize)
        return status == noErr && dataSize > 0
    }
    
    /// すべてのオーディオデバイスの情報を取得します
    public func devices() -> [AudioDevice] {
        return getDeviceIDs().map { id in
            let name = getDeviceName(deviceID: id)
            let isInput = hasStreams(deviceID: id, scope: kAudioObjectPropertyScopeInput)
            let isOutput = hasStreams(deviceID: id, scope: kAudioObjectPropertyScopeOutput)
            return AudioDevice(id: id, uid: "", name: name, isInput: isInput, isOutput: isOutput)
        }
    }
    
    public func outputDevices() -> [AudioDevice] {
        return devices().filter { $0.isOutput }
    }
    
    public func inputDevices() -> [AudioDevice] {
        return devices().filter { $0.isInput }
    }
    
    /// デフォルトの出力（スピーカー等）デバイスIDを取得します
    public func defaultOutputDeviceID() -> AudioDeviceID? {
        let result: Result<AudioDeviceID, AudioError> = AudioProperty.getProperty(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultOutputDevice,
            defaultValue: 0
        )
        switch result {
        case .success(let id) where id != 0: return id
        default: return nil
        }
    }
    
    /// デフォルトの入力（マイク等）デバイスIDを取得します
    public func defaultInputDeviceID() -> AudioDeviceID? {
        let result: Result<AudioDeviceID, AudioError> = AudioProperty.getProperty(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultInputDevice,
            defaultValue: 0
        )
        switch result {
        case .success(let id) where id != 0: return id
        default: return nil
        }
    }
    
    /// 特定のデバイスIDの名前を取得します
    public func getDeviceName(deviceID: AudioDeviceID) -> String {
        let result = AudioProperty.getStringProperty(
            objectID: deviceID,
            selector: kAudioObjectPropertyName
        )
        switch result {
        case .success(let name): return name
        case .failure: return "Unknown Device"
        }
    }
    
    /// 現在のデフォルト出力デバイスを AudioDevice モデルとして取得します
    public func defaultOutput() -> AudioDevice? {
        guard let deviceID = defaultOutputDeviceID() else { return nil }
        
        let name = getDeviceName(deviceID: deviceID)
        let isInput = hasStreams(deviceID: deviceID, scope: kAudioObjectPropertyScopeInput)
        let isOutput = hasStreams(deviceID: deviceID, scope: kAudioObjectPropertyScopeOutput)
        
        return AudioDevice(id: deviceID, uid: "", name: name, isInput: isInput, isOutput: isOutput)
    }
    
    public func defaultInput() -> AudioDevice? {
        guard let deviceID = defaultInputDeviceID() else { return nil }
        
        let name = getDeviceName(deviceID: deviceID)
        let isInput = hasStreams(deviceID: deviceID, scope: kAudioObjectPropertyScopeInput)
        let isOutput = hasStreams(deviceID: deviceID, scope: kAudioObjectPropertyScopeOutput)
        
        return AudioDevice(id: deviceID, uid: "", name: name, isInput: isInput, isOutput: isOutput)
    }
    
    public func setOutput(_ device: AudioDevice) {
        _ = AudioProperty.setProperty(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultOutputDevice,
            value: device.id
        )
    }
    
    public func setInput(_ device: AudioDevice) {
        _ = AudioProperty.setProperty(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultInputDevice,
            value: device.id
        )
    }
    
    // MARK: - Format Info
    
    /// 特定のデバイスの物理的なフォーマット（ビット深度、サンプルレート、コーデックなど）を取得します
    public func getPhysicalFormat(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> AudioFormatInfo? {
        let result: Result<AudioStreamBasicDescription, AudioError> = AudioProperty.getProperty(
            objectID: deviceID,
            selector: kAudioStreamPropertyPhysicalFormat,
            scope: scope,
            defaultValue: AudioStreamBasicDescription()
        )
        
        switch result {
        case .success(let desc):
            return AudioFormatInfo(
                sampleRate: desc.mSampleRate,
                channels: desc.mChannelsPerFrame,
                bitDepth: desc.mBitsPerChannel,
                formatName: getAudioFormat(desc.mFormatID),
                formatFlagsName: getAudioFormatFlag(desc.mFormatFlags)
            )
        case .failure:
            return nil
        }
    }
    
    private func getAudioFormatFlag(_ value: AudioFormatFlags) -> String {
        var flags = [String]()
        
        if (value & kAudioFormatFlagIsFloat) == kAudioFormatFlagIsFloat { flags.append("Float") }
        if (value & kAudioFormatFlagIsBigEndian) == kAudioFormatFlagIsBigEndian { flags.append("Big") }
        if (value & kAudioFormatFlagIsSignedInteger) == kAudioFormatFlagIsSignedInteger { flags.append("Integer") }
        if (value & kAudioFormatFlagIsAlignedHigh) == kAudioFormatFlagIsAlignedHigh { flags.append("Align-High") }
        if (value & kAudioFormatFlagIsNonInterleaved) == kAudioFormatFlagIsNonInterleaved { flags.append("Non-Interleaved") }
        if (value & kAudioFormatFlagIsNonMixable) == kAudioFormatFlagIsNonMixable { flags.append("Non-Mixable") }
        if (value & kAudioFormatFlagsAreAllClear) == kAudioFormatFlagsAreAllClear { flags.append("All-Clear") }
        
        let v = flags.joined(separator: " ")
        return v == "" ? "Undefined" : v
    }
    
    private func getAudioFormat(_ value: AudioFormatID) -> String {
        switch value {
        case kAudioFormatLinearPCM: return "PCM"
        case kAudioFormatAC3: return "AC3"
        case kAudioFormat60958AC3: return "AC3"
        case kAudioFormatAppleIMA4: return "IMA4"
        case kAudioFormatMPEG4AAC: return "AAC"
        case kAudioFormatMPEG4CELP: return "CELP"
        case kAudioFormatMPEG4HVXC: return "HVXC"
        case kAudioFormatMPEG4TwinVQ: return "TwinVQ"
        case kAudioFormatMACE3: return "MACE3"
        case kAudioFormatMACE6: return "MACE6"
        case kAudioFormatULaw: return "ULaw"
        case kAudioFormatALaw: return "ALaw"
        case kAudioFormatQDesign: return "QDesign"
        case kAudioFormatQDesign2: return "QDesign2"
        case kAudioFormatQUALCOMM: return "QUALCOMM"
        case kAudioFormatMPEGLayer1: return "MPEG1"
        case kAudioFormatMPEGLayer2: return "MPEG2"
        case kAudioFormatMPEGLayer3: return "MPEG3"
        case kAudioFormatTimeCode: return "TimeCode"
        case kAudioFormatMIDIStream: return "MIDIStream"
        case kAudioFormatParameterValueStream: return "ParameterValueStream"
        case kAudioFormatAppleLossless: return "AppleLossless"
        case kAudioFormatMPEG4AAC_HE: return "AAC-HE"
        case kAudioFormatMPEG4AAC_LD: return "AAC-LD"
        case kAudioFormatMPEG4AAC_ELD: return "AAC-ELD"
        case kAudioFormatMPEG4AAC_ELD_SBR: return "AAC-ELD-SBR"
        case kAudioFormatMPEG4AAC_HE_V2: return "AAC-HE-V2"
        case kAudioFormatMPEG4AAC_Spatial: return "AAC-Spatial"
        case kAudioFormatAMR: return "AMR"
        case kAudioFormatAudible: return "Audible"
        case kAudioFormatiLBC: return "iLBC"
        case kAudioFormatDVIIntelIMA: return "DVIIntelIMA"
        case kAudioFormatMicrosoftGSM: return "MicrosoftGSM"
        case kAudioFormatAES3: return "AES3"
        case kAudioFormatAMR_WB: return "AMR-WB"
        case kAudioFormatEnhancedAC3: return "EnhancedAC3"
        case kAudioFormatMPEG4AAC_ELD_V2: return "AAC-ELD-V2"
        case kAudioFormatFLAC: return "FLAC"
        case kAudioFormatMPEGD_USAC: return "USAC"
        case kAudioFormatOpus: return "Opus"
        default: return "Undefined"
        }
    }
}
