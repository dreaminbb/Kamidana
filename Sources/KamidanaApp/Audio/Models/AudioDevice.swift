import CoreAudio
import Foundation

public struct AudioDevice: Equatable, Identifiable {
    public let id: AudioDeviceID
    public let uid: String
    public let name: String
    public let isInput: Bool
    public let isOutput: Bool
    
    public init(id: AudioDeviceID, uid: String, name: String, isInput: Bool, isOutput: Bool) {
        self.id = id
        self.uid = uid
        self.name = name
        self.isInput = isInput
        self.isOutput = isOutput
    }
}
