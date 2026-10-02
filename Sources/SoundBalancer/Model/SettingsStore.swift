import Foundation

public final class SettingsStore: @unchecked Sendable {
    public static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    private let keyAppGains = "com.timstebner.SoundBalancer.appGains"
    private let keyAppMutes = "com.timstebner.SoundBalancer.appMutes"
    private let keyNativeRoutingApps = "com.timstebner.SoundBalancer.nativeRoutingApps"
    private let keySkipAppsDuringInputCapture = "com.timstebner.SoundBalancer.skipAppsDuringInputCapture"

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

    public func loadNativeRoutingApps() -> Set<String> {
        Set(defaults.stringArray(forKey: keyNativeRoutingApps) ?? [])
    }

    public func saveNativeRoutingApps(_ apps: Set<String>) {
        defaults.set(Array(apps), forKey: keyNativeRoutingApps)
    }

    public func loadSkipAppsDuringInputCapture() -> Bool {
        defaults.object(forKey: keySkipAppsDuringInputCapture) as? Bool ?? true
    }

    public func saveSkipAppsDuringInputCapture(_ skip: Bool) {
        defaults.set(skip, forKey: keySkipAppsDuringInputCapture)
    }
}
