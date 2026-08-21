import Foundation
import CoreAudio

public struct AudioFormatInfo: Equatable {
    public let sampleRate: Double
    public let channels: UInt32
    public let bitDepth: UInt32
    public let formatName: String
    public let formatFlagsName: String
    
    public init(sampleRate: Double, channels: UInt32, bitDepth: UInt32, formatName: String, formatFlagsName: String) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitDepth = bitDepth
        self.formatName = formatName
        self.formatFlagsName = formatFlagsName
    }
}
