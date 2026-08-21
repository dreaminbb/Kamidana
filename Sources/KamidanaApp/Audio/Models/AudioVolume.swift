import Foundation

public struct AudioVolume: Equatable {
    public var value: Float
    public var muted: Bool
    
    public init(value: Float, muted: Bool) {
        self.value = value
        self.muted = muted
    }
}
