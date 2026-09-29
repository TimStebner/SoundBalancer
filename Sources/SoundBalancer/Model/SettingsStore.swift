import Foundation

public final class SettingsStore: @unchecked Sendable {
    public static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    private let keyAppGains = "com.timstebner.SoundBalancer.appGains"
    private let keyAppMutes = "com.timstebner.SoundBalancer.appMutes"
    private let keyEQGains = "com.timstebner.SoundBalancer.eqGains"
    private let keyEQPresetName = "com.timstebner.SoundBalancer.eqPresetName"
    private let keyEQEnabled = "com.timstebner.SoundBalancer.eqEnabled"

    public func loadGains() -> [String: Double] {
        defaults.dictionary(forKey: keyAppGains) as? [String: Double] ?? [:]
    }

    public func saveGains(_ gains: [String: Double]) {
        defaults.set(gains, forKey: keyAppGains)
    }

    public func loadMutes() -> Set<String> {
        let array = defaults.stringArray(forKey: keyAppMutes) ?? []
        return Set(array)
    }

    public func saveMutes(_ mutes: Set<String>) {
        defaults.set(Array(mutes), forKey: keyAppMutes)
    }

    public func loadEQGains() -> [Float] {
        let array = defaults.array(forKey: keyEQGains) as? [Double]
        if let array, array.count == 10 {
            return array.map { Float($0) }
        }
        return [Float](repeating: 0.0, count: 10)
    }

    public func saveEQGains(_ gains: [Float]) {
        defaults.set(gains.map { Double($0) }, forKey: keyEQGains)
    }

    public func loadEQPresetName() -> String {
        defaults.string(forKey: keyEQPresetName) ?? "Flat"
    }

    public func saveEQPresetName(_ name: String) {
        defaults.set(name, forKey: keyEQPresetName)
    }

    public func loadEQEnabled() -> Bool {
        defaults.bool(forKey: keyEQEnabled)
    }

    public func saveEQEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: keyEQEnabled)
    }
}
