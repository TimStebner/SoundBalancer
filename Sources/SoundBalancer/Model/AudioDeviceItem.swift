import CoreAudio
import Foundation

public struct AudioDeviceItem: Identifiable, Hashable, Sendable {
    public let id: AudioDeviceID
    public let uid: String
    public let name: String
    public let symbolName: String
    public let isInput: Bool
    public let isOutput: Bool

    public init(
        id: AudioDeviceID,
        uid: String,
        name: String,
        symbolName: String,
        isInput: Bool,
        isOutput: Bool
    ) {
        self.id = id
        self.uid = uid
        self.name = name
        self.symbolName = symbolName
        self.isInput = isInput
        self.isOutput = isOutput
    }
}
