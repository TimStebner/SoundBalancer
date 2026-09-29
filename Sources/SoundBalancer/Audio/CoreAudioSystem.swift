import AudioToolbox
import CoreAudio
import Foundation
import os

public enum CA {
    private static let logger = Logger(subsystem: "com.timstebner.SoundBalancer", category: "CoreAudio")

    public static let system = AudioObjectID(kAudioObjectSystemObject)

    public static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
    }

    public static func value<T>(
        _ objectID: AudioObjectID,
        _ address: AudioObjectPropertyAddress,
        fallback: T
    ) -> T {
        var addr = address
        var val = fallback
        var size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutablePointer(to: &val) { ptr in
            AudioObjectGetPropertyData(objectID, &addr, 0, nil, &size, ptr)
        }
        guard status == noErr else { return fallback }
        return val
    }

    public static func setValue<T>(
        _ objectID: AudioObjectID,
        _ address: AudioObjectPropertyAddress,
        _ value: T
    ) -> Bool {
        var addr = address
        var val = value
        let size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafePointer(to: &val) { ptr in
            AudioObjectSetPropertyData(objectID, &addr, 0, nil, size, ptr)
        }
        if status != noErr {
            logger.error("Failed to set property \(addr.mSelector) on object \(objectID): \(status)")
            return false
        }
        return true
    }

    public static func string(
        _ objectID: AudioObjectID,
        _ address: AudioObjectPropertyAddress
    ) -> String? {
        var addr = address
        var cfStr: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &cfStr) { ptr in
            AudioObjectGetPropertyData(objectID, &addr, 0, nil, &size, ptr)
        }
        guard status == noErr, let str = cfStr as String? else { return nil }
        return str
    }

    public static func array<T>(
        _ objectID: AudioObjectID,
        _ address: AudioObjectPropertyAddress,
        of type: T.Type
    ) -> [T] {
        var addr = address
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(objectID, &addr, 0, nil, &size) == noErr, size > 0 else {
            return []
        }
        let count = Int(size) / MemoryLayout<T>.stride
        guard count > 0 else { return [] }
        return [T](unsafeUninitializedCapacity: count) { buffer, initializedCount in
            guard let base = buffer.baseAddress else {
                initializedCount = 0
                return
            }
            let status = AudioObjectGetPropertyData(objectID, &addr, 0, nil, &size, base)
            if status == noErr {
                initializedCount = Int(size) / MemoryLayout<T>.stride
            } else {
                initializedCount = 0
            }
        }
    }

    public final class ListenerToken: @unchecked Sendable {
        private let objectID: AudioObjectID
        private var address: AudioObjectPropertyAddress
        private let block: AudioObjectPropertyListenerBlock

        fileprivate init(
            objectID: AudioObjectID,
            address: AudioObjectPropertyAddress,
            block: @escaping AudioObjectPropertyListenerBlock
        ) {
            self.objectID = objectID
            self.address = address
            self.block = block
        }

        deinit {
            AudioObjectRemovePropertyListenerBlock(objectID, &address, .main, block)
        }
    }

    public static func listen(
        _ objectID: AudioObjectID,
        _ address: AudioObjectPropertyAddress,
        on queue: DispatchQueue = .main,
        handler: @escaping @Sendable () -> Void
    ) -> ListenerToken? {
        var addr = address
        let block: AudioObjectPropertyListenerBlock = { _, _ in
            queue.async { handler() }
        }
        let status = AudioObjectAddPropertyListenerBlock(objectID, &addr, .main, block)
        guard status == noErr else {
            logger.error("Failed to add listener for \(addr.mSelector) on \(objectID): \(status)")
            return nil
        }
        return ListenerToken(objectID: objectID, address: addr, block: block)
    }
}
