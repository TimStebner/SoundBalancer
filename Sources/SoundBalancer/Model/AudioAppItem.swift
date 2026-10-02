import AppKit
import CoreAudio
import Foundation

public struct AudioAppItem: Identifiable, Hashable, @unchecked Sendable {
    public let id: AudioObjectID
    public let pid: pid_t
    public let name: String
    public let bundleID: String?
    public let icon: NSImage?
    public let isRunningOutput: Bool
    public let isRunningInput: Bool

    public init(
        id: AudioObjectID,
        pid: pid_t,
        name: String,
        bundleID: String?,
        icon: NSImage?,
        isRunningOutput: Bool,
        isRunningInput: Bool = false
    ) {
        self.id = id
        self.pid = pid
        self.name = name
        self.bundleID = bundleID
        self.icon = icon
        self.isRunningOutput = isRunningOutput
        self.isRunningInput = isRunningInput
    }

    public static func == (lhs: AudioAppItem, rhs: AudioAppItem) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name &&
            lhs.isRunningOutput == rhs.isRunningOutput && lhs.isRunningInput == rhs.isRunningInput
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
