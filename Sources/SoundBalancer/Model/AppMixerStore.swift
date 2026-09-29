import AppKit
import CoreAudio
import Foundation
import Observation

@Observable
public final class AppMixerStore: @unchecked Sendable {
    public enum Tab: String, CaseIterable, Identifiable, Sendable {
        case mixer = "Mixer"
        case equalizer = "Equalizer"

        public var id: String { rawValue }
    }

    public var selectedTab: Tab = .mixer

    public let processMonitor = AudioProcessMonitor()
    public let permission = AudioPermission()
    private let engine = TapMixerEngine()
    private let settings = SettingsStore.shared

    public private(set) var outputDevices: [AudioDeviceItem] = []
    public private(set) var inputDevices: [AudioDeviceItem] = []
    public private(set) var selectedOutputID: AudioDeviceID = AudioDeviceID(kAudioObjectUnknown)
    public private(set) var selectedInputID: AudioDeviceID = AudioDeviceID(kAudioObjectUnknown)

    private var gains: [String: Double] = [:]
    private var mutes: Set<String> = []

    public var isEQEnabled: Bool = false {
        didSet {
            engine.filterBank.setBypassed(!isEQEnabled)
            settings.saveEQEnabled(isEQEnabled)
        }
    }
    public var eqGains: [Float] = [Float](repeating: 0.0, count: 10)
    public var selectedPresetName: String = "Flat"

    public var isMasterEnabled: Bool = true {
        didSet {
            if isMasterEnabled {
                reconcile()
            } else {
                engine.teardownAll()
            }
        }
    }

    private var outputDeviceListener: CA.ListenerToken?
    private var inputDeviceListener: CA.ListenerToken?
    private var devicesListListener: CA.ListenerToken?

    public init() {
        self.gains = settings.loadGains()
        self.mutes = settings.loadMutes()
        self.eqGains = settings.loadEQGains()
        self.selectedPresetName = settings.loadEQPresetName()
        self.isEQEnabled = settings.loadEQEnabled()

        engine.filterBank.setGains(eqGains)
        engine.filterBank.setBypassed(!isEQEnabled)

        refreshDevices()

        processMonitor.onAppsChanged = { [weak self] in
            DispatchQueue.main.async { self?.reconcile() }
        }

        outputDeviceListener = CA.listen(
            CA.system,
            CA.address(kAudioHardwarePropertyDefaultOutputDevice)
        ) { [weak self] in
            self?.refreshDevices()
            self?.rebuildAllTaps()
        }

        inputDeviceListener = CA.listen(
            CA.system,
            CA.address(kAudioHardwarePropertyDefaultInputDevice)
        ) { [weak self] in
            self?.refreshDevices()
        }

        devicesListListener = CA.listen(
            CA.system,
            CA.address(kAudioHardwarePropertyDevices)
        ) { [weak self] in
            self?.refreshDevices()
        }

        reconcile()
    }

    public func appKey(for app: AudioAppItem) -> String {
        app.bundleID ?? "pid:\(app.pid)"
    }

    public func volume(for app: AudioAppItem) -> Double {
        gains[appKey(for: app)] ?? 1.0
    }

    public func isMuted(for app: AudioAppItem) -> Bool {
        mutes.contains(appKey(for: app))
    }

    public func isDefault(for app: AudioAppItem) -> Bool {
        let key = appKey(for: app)
        return !mutes.contains(key) && (gains[key] ?? 1.0) == 1.0
    }

    public func setVolume(_ value: Double, for app: AudioAppItem) {
        let clamped = max(0.0, min(4.0, value))
        let key = appKey(for: app)
        gains[key] = clamped
        settings.saveGains(gains)

        ensurePermissionThenReconcile()
    }

    public func toggleMute(for app: AudioAppItem) {
        let key = appKey(for: app)
        if mutes.contains(key) {
            mutes.remove(key)
        } else {
            mutes.insert(key)
        }
        settings.saveMutes(mutes)

        ensurePermissionThenReconcile()
    }

    public func resetApp(_ app: AudioAppItem) {
        let key = appKey(for: app)
        gains.removeValue(forKey: key)
        mutes.remove(key)
        settings.saveGains(gains)
        settings.saveMutes(mutes)

        engine.dropTap(for: app.id)
        reconcile()
    }

    public func refreshDevices() {
        let outs = AudioDevices.outputDevices()
        let ins = AudioDevices.inputDevices()
        let currentOut = AudioDevices.defaultOutputDeviceID() ?? AudioDeviceID(kAudioObjectUnknown)
        let currentIn = AudioDevices.defaultInputDeviceID() ?? AudioDeviceID(kAudioObjectUnknown)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.outputDevices = outs
            self.inputDevices = ins
            self.selectedOutputID = currentOut
            self.selectedInputID = currentIn
        }
    }

    public func selectOutputDevice(_ device: AudioDeviceItem) {
        AudioDevices.setDefaultOutputDevice(device.id)
        selectedOutputID = device.id
    }

    public func selectInputDevice(_ device: AudioDeviceItem) {
        AudioDevices.setDefaultInputDevice(device.id)
        selectedInputID = device.id
    }

    public func setEQGain(bandIndex: Int, gainDB: Float) {
        guard bandIndex >= 0, bandIndex < eqGains.count else { return }
        eqGains[bandIndex] = gainDB
        selectedPresetName = "Custom"
        engine.filterBank.setGains(eqGains)
        settings.saveEQGains(eqGains)
        settings.saveEQPresetName("Custom")
    }

    public func applyPreset(_ preset: EQPreset) {
        eqGains = preset.gains
        selectedPresetName = preset.name
        engine.filterBank.setGains(eqGains)
        settings.saveEQGains(eqGains)
        settings.saveEQPresetName(preset.name)
    }

    public func resetEQ() {
        applyPreset(EQPreset.flat)
    }

    private func effectiveGain(for app: AudioAppItem) -> Float32? {
        guard isMasterEnabled else { return nil }
        let key = appKey(for: app)
        let isMuted = mutes.contains(key)
        let userVolume = isMuted ? 0.0 : (gains[key] ?? 1.0)

        if userVolume == 1.0 && !engine.hasTap(for: app.id) {
            return nil
        }
        return Float32(userVolume)
    }

    public func reconcile() {
        guard isMasterEnabled, permission.isAuthorized else { return }
        engine.reconcile(apps: processMonitor.apps, effectiveGain: effectiveGain)
    }

    public func rebuildAllTaps() {
        guard isMasterEnabled, permission.isAuthorized else { return }
        engine.rebuildAll(apps: processMonitor.apps, effectiveGain: effectiveGain)
    }

    private func ensurePermissionThenReconcile() {
        switch permission.status {
        case .authorized:
            reconcile()
        case .unknown:
            permission.request { [weak self] in self?.reconcile() }
        case .denied:
            break
        }
    }

    public func teardown() {
        engine.teardownAll()
    }
}
