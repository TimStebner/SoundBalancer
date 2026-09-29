import AudioToolbox
import CoreAudio
import Foundation
import os

public enum AudioDevices {
    private static let logger = Logger(subsystem: "com.timstebner.SoundBalancer", category: "AudioDevices")

    public static let aggregateUIDPrefix = "com.timstebner.SoundBalancer.aggregate."

    public static func allDeviceIDs() -> [AudioDeviceID] {
        CA.array(CA.system, CA.address(kAudioHardwarePropertyDevices), of: AudioDeviceID.self)
    }

    public static func defaultOutputDeviceID() -> AudioDeviceID? {
        let id = CA.value(
            CA.system,
            CA.address(kAudioHardwarePropertyDefaultOutputDevice),
            fallback: AudioDeviceID(kAudioObjectUnknown)
        )
        return id != kAudioObjectUnknown ? id : nil
    }

    public static func setDefaultOutputDevice(_ deviceID: AudioDeviceID) {
        guard deviceID != kAudioObjectUnknown else { return }
        _ = CA.setValue(
            CA.system,
            CA.address(kAudioHardwarePropertyDefaultOutputDevice),
            deviceID
        )
    }

    public static func defaultInputDeviceID() -> AudioDeviceID? {
        let id = CA.value(
            CA.system,
            CA.address(kAudioHardwarePropertyDefaultInputDevice),
            fallback: AudioDeviceID(kAudioObjectUnknown)
        )
        return id != kAudioObjectUnknown ? id : nil
    }

    public static func setDefaultInputDevice(_ deviceID: AudioDeviceID) {
        guard deviceID != kAudioObjectUnknown else { return }
        _ = CA.setValue(
            CA.system,
            CA.address(kAudioHardwarePropertyDefaultInputDevice),
            deviceID
        )
    }

    public static func name(of deviceID: AudioDeviceID) -> String? {
        CA.string(deviceID, CA.address(kAudioObjectPropertyName))
    }

    public static func persistentUID(of deviceID: AudioDeviceID) -> String? {
        CA.string(deviceID, CA.address(kAudioDevicePropertyDeviceUID))
    }

    public static func transportType(of deviceID: AudioDeviceID) -> UInt32 {
        CA.value(deviceID, CA.address(kAudioDevicePropertyTransportType), fallback: 0)
    }

    public static func isSoundBalancerAggregate(_ deviceID: AudioDeviceID) -> Bool {
        guard let uid = persistentUID(of: deviceID) else { return false }
        return uid.hasPrefix(aggregateUIDPrefix)
    }

    public static func hasOutputChannels(_ deviceID: AudioDeviceID) -> Bool {
        outputChannelCount(deviceID) > 0
    }

    public static func hasInputChannels(_ deviceID: AudioDeviceID) -> Bool {
        inputChannelCount(deviceID) > 0
    }

    public static func outputChannelCount(_ deviceID: AudioDeviceID) -> Int {
        bufferChannels(of: deviceID, scope: kAudioObjectPropertyScopeOutput).reduce(0, +)
    }

    public static func inputChannelCount(_ deviceID: AudioDeviceID) -> Int {
        bufferChannels(of: deviceID, scope: kAudioObjectPropertyScopeInput).reduce(0, +)
    }

    public static func bufferChannels(
        of deviceID: AudioDeviceID,
        scope: AudioObjectPropertyScope
    ) -> [Int] {
        var addr = CA.address(kAudioDevicePropertyStreamConfiguration, scope: scope)
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &addr, 0, nil, &dataSize) == noErr, dataSize > 0 else {
            return []
        }
        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &dataSize, raw) == noErr else {
            return []
        }
        let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return list.map { Int($0.mNumberChannels) }
    }

    public static func outputSymbolName(for deviceID: AudioDeviceID) -> String {
        let nameLower = (name(of: deviceID) ?? "").lowercased()
        if nameLower.contains("airpods max") {
            return "headphones"
        } else if nameLower.contains("airpods pro") {
            return "airpodspro"
        } else if nameLower.contains("airpods") {
            return "airpods"
        }

        switch transportType(of: deviceID) {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return "headphones"
        case kAudioDeviceTransportTypeBuiltIn:
            return "laptopcomputer"
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort:
            return "display"
        case kAudioDeviceTransportTypeUSB:
            return "speaker.wave.2"
        case kAudioDeviceTransportTypeAirPlay:
            return "airplayaudio"
        default:
            return "speaker.wave.2"
        }
    }

    public static func inputSymbolName(for deviceID: AudioDeviceID) -> String {
        let nameLower = (name(of: deviceID) ?? "").lowercased()
        if nameLower.contains("airpods") {
            return "airpodspro"
        }
        switch transportType(of: deviceID) {
        case kAudioDeviceTransportTypeBuiltIn:
            return "mic.fill"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return "mic.circle"
        case kAudioDeviceTransportTypeUSB:
            return "mic.and.signal.meter.fill"
        default:
            return "mic.fill"
        }
    }

    public static func outputDevices() -> [AudioDeviceItem] {
        allDeviceIDs()
            .filter { hasOutputChannels($0) && !isSoundBalancerAggregate($0) }
            .compactMap { id -> AudioDeviceItem? in
                guard let name = name(of: id), let uid = persistentUID(of: id) else { return nil }
                return AudioDeviceItem(
                    id: id,
                    uid: uid,
                    name: name,
                    symbolName: outputSymbolName(for: id),
                    isInput: false,
                    isOutput: true
                )
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public static func inputDevices() -> [AudioDeviceItem] {
        allDeviceIDs()
            .filter { hasInputChannels($0) && !isSoundBalancerAggregate($0) }
            .compactMap { id -> AudioDeviceItem? in
                guard let name = name(of: id), let uid = persistentUID(of: id) else { return nil }
                return AudioDeviceItem(
                    id: id,
                    uid: uid,
                    name: name,
                    symbolName: inputSymbolName(for: id),
                    isInput: true,
                    isOutput: false
                )
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
