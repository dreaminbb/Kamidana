import CoreAudio
import Foundation

enum AudioError: Error {
    case getPropertyFailed(OSStatus)
    case setPropertyFailed(OSStatus)
    case unknown
}

class AudioProperty {
    
    /// CoreAudioから値を取得する共通ユーティリティ
    /// - Parameters:
    ///   - objectID: 対象のオブジェクトID (システム全体なら kAudioObjectSystemObject)
    ///   - selector: 取得したいプロパティ (例: kAudioHardwarePropertyDefaultOutputDevice)
    ///   - scope: 入力か出力か (例: kAudioObjectPropertyScopeGlobal)
    ///   - element: 要素 (例: kAudioObjectPropertyElementMain)
    static func getProperty<T>(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain,
        defaultValue: T
    ) -> Result<T, AudioError> {
        
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
        
        var dataSize = UInt32(MemoryLayout<T>.size)
        var data = defaultValue
        
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, &data)
        
        if status == noErr {
            return .success(data)
        } else {
            return .failure(.getPropertyFailed(status))
        }
    }
    
    /// CoreAudioから配列サイズを取得し、配列データとして取得するユーティリティ
    static func getArrayProperty<T>(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> Result<[T], AudioError> {
        
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &dataSize)
        
        guard status == noErr, dataSize > 0 else {
            return status == noErr ? .success([]) : .failure(.getPropertyFailed(status))
        }
        
        let count = Int(dataSize) / MemoryLayout<T>.size
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: count)
        defer { pointer.deallocate() }
        
        status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, pointer)
        
        if status == noErr {
            let buffer = UnsafeBufferPointer(start: pointer, count: count)
            return .success(Array(buffer))
        } else {
            return .failure(.getPropertyFailed(status))
        }
    }
    
    /// CoreAudioから文字列(CFString)を取得するユーティリティ
    static func getStringProperty(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> Result<String, AudioError> {
        
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
        
        var dataSize = UInt32(MemoryLayout<CFString?>.size)
        var cfString: CFString? = nil
        
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, &cfString)
        
        if status == noErr, let string = cfString as String? {
            return .success(string)
        } else {
            return .failure(.getPropertyFailed(status))
        }
    }
    
    /// CoreAudioのプロパティに値を設定する共通ユーティリティ
    static func setProperty<T>(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain,
        value: T
    ) -> Result<Void, AudioError> {
        
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
        
        var dataSize = UInt32(MemoryLayout<T>.size)
        var data = value
        
        let status = AudioObjectSetPropertyData(objectID, &address, 0, nil, dataSize, &data)
        
        if status == noErr {
            return .success(())
        } else {
            return .failure(.setPropertyFailed(status))
        }
    }
}
