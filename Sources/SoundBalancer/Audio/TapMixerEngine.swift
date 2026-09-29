import AudioToolbox
import CoreAudio
import Foundation
import os

public final class TapMixerEngine: @unchecked Sendable {
    private let ioQueue = DispatchQueue(label: "com.timstebner.SoundBalancer.tap-io", qos: .userInitiated)
    private var taps: [AudioObjectID: ProcessTap] = [:]
    public let filterBank = EQFilterBank()

    private static let logger = Logger(subsystem: "com.timstebner.SoundBalancer", category: "TapMixerEngine")

    public init() {}

    deinit {
        teardownAll()
    }

    public func hasTap(for processObjectID: AudioObjectID) -> Bool {
        taps[processObjectID] != nil
    }

    public func reconcile(
        apps: [AudioAppItem],
        effectiveGain: (AudioAppItem) -> Float32?
    ) {
        let liveAppIDs = Set(apps.map(\.id))
        for id in taps.keys where !liveAppIDs.contains(id) {
            taps[id]?.stop()
            taps.removeValue(forKey: id)
        }

        guard let outputID = AudioDevices.defaultOutputDeviceID(),
              let outputUID = AudioDevices.persistentUID(of: outputID) else {
            return
        }

        let compensation = loudnessCompensation(for: outputID)

        for app in apps {
            guard let gain = effectiveGain(app) else {
                if let existing = taps[app.id] {
                    existing.stop()
                    taps.removeValue(forKey: app.id)
                }
                continue
            }

            let voiceComp = voiceCompensation(for: app)
            let compensatedGain = gain * compensation * voiceComp

            if let existing = taps[app.id] {
                existing.setGain(compensatedGain)
            } else {
                let tap = ProcessTap(
                    processObjectID: app.id,
                    outputDeviceUID: outputUID,
                    initialGain: compensatedGain,
                    filterBank: filterBank,
                    queue: ioQueue
                )
                if tap.start() {
                    taps[app.id] = tap
                    Self.logger.info("Started process tap for app \(app.name) (\(app.id)) with gain \(compensatedGain)")
                }
            }
        }
    }

    public func dropTap(for processObjectID: AudioObjectID) {
        taps[processObjectID]?.stop()
        taps.removeValue(forKey: processObjectID)
    }

    public func rebuildAll(
        apps: [AudioAppItem],
        effectiveGain: (AudioAppItem) -> Float32?
    ) {
        teardownAll()
        reconcile(apps: apps, effectiveGain: effectiveGain)
    }

    public func teardownAll() {
        for tap in taps.values {
            tap.stop()
        }
        taps.removeAll()
    }

    private func loudnessCompensation(for deviceID: AudioDeviceID) -> Float32 {
        let channels = AudioDevices.outputChannelCount(deviceID)
        return max(1.0, Float32(channels) / 2.0)
    }

    private func voiceCompensation(for app: AudioAppItem) -> Float32 {
        let b = (app.bundleID ?? app.name).lowercased()
        if b.contains("whatsapp") || b.contains("facetime") || b.contains("zoom") || b.contains("teams") || b.contains("skype") || b.contains("telegram") {
            return 2.0 // +6 dB mixdown compensation for mono voice communication streams
        }
        return 1.0
    }
}
