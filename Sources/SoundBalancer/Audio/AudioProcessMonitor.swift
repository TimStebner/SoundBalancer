import AppKit
import CoreAudio
import Darwin
import Foundation
import Observation
import os

@Observable
public final class AudioProcessMonitor: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.timstebner.SoundBalancer", category: "ProcessMonitor")

    public private(set) var apps: [AudioAppItem] = []
    public var onAppsChanged: (@Sendable () -> Void)?

    private var listListener: CA.ListenerToken?
    private var timer: Timer?
    private static let ownPID = getpid()

    public init() {
        refresh()

        listListener = CA.listen(CA.system, CA.address(kAudioHardwarePropertyProcessObjectList)) { [weak self] in
            self?.refresh()
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        timer?.invalidate()
    }

    public func refresh() {
        let processIDs = CA.array(
            CA.system,
            CA.address(kAudioHardwarePropertyProcessObjectList),
            of: AudioObjectID.self
        )

        var discovered: [(item: AudioAppItem, key: String)] = []
        var inputCaptureKeys = Set<String>()
        for id in processIDs {
            let isRunningOutput = CA.value(
                id,
                CA.address(kAudioProcessPropertyIsRunningOutput),
                fallback: UInt32(0)
            ) != 0
            let isRunningInput = CA.value(
                id,
                CA.address(kAudioProcessPropertyIsRunningInput),
                fallback: UInt32(0)
            ) != 0

            guard isRunningOutput || isRunningInput else { continue }

            let pid = CA.value(
                id,
                CA.address(kAudioProcessPropertyPID),
                fallback: pid_t(-1)
            )

            guard pid > 0, pid != Self.ownPID else { continue }

            let bundleID = CA.string(id, CA.address(kAudioProcessPropertyBundleID))
            let ownerApp = Self.resolveOwningApplication(pid: pid)

            guard ownerApp != nil || !(bundleID?.isEmpty ?? true) else { continue }

            let resolvedName = ownerApp?.localizedName ?? Self.fallbackName(bundleID: bundleID, pid: pid)
            let resolvedBundleID = ownerApp?.bundleIdentifier ?? bundleID
            let resolvedIcon = ownerApp?.icon
            let key = resolvedBundleID ?? "pid:\(pid)"

            if isRunningInput {
                inputCaptureKeys.insert(key)
            }

            guard isRunningOutput else { continue }

            discovered.append((
                item: AudioAppItem(
                    id: id,
                    pid: pid,
                    name: resolvedName,
                    bundleID: resolvedBundleID,
                    icon: resolvedIcon,
                    isRunningOutput: true
                ),
                key: key
            ))
        }

        let sorted = discovered.sorted {
            $0.item.name.localizedStandardCompare($1.item.name) == .orderedAscending
        }

        var unique: [AudioAppItem] = []
        var seenKeys = Set<String>()
        for entry in sorted {
            let deduplicationKey = entry.item.bundleID ?? entry.item.name
            if seenKeys.insert(deduplicationKey).inserted {
                let item = entry.item
                unique.append(
                    AudioAppItem(
                        id: item.id,
                        pid: item.pid,
                        name: item.name,
                        bundleID: item.bundleID,
                        icon: item.icon,
                        isRunningOutput: item.isRunningOutput,
                        isRunningInput: inputCaptureKeys.contains(entry.key)
                    )
                )
            }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.apps != unique {
                self.apps = unique
                self.onAppsChanged?()
            }
        }
    }

    public static func resolveOwningApplication(pid: pid_t) -> NSRunningApplication? {
        var currentPID = pid
        var depth = 0
        while currentPID > 1 && depth < 8 {
            if let app = NSRunningApplication(processIdentifier: currentPID) {
                if app.activationPolicy == .regular || app.activationPolicy == .accessory {
                    return app
                }
            }
            guard let parent = parentPID(of: currentPID), parent != currentPID else { break }
            currentPID = parent
            depth += 1
        }
        return NSRunningApplication(processIdentifier: pid)
    }

    private static func parentPID(of pid: pid_t) -> pid_t? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        let result = mib.withUnsafeMutableBufferPointer { mibPtr in
            sysctl(mibPtr.baseAddress, UInt32(mibPtr.count), &info, &size, nil, 0)
        }
        guard result == 0, size > 0 else { return nil }
        let ppid = info.kp_eproc.e_ppid
        return ppid > 0 ? ppid : nil
    }

    private static func fallbackName(bundleID: String?, pid: pid_t) -> String {
        if let bundleID, !bundleID.isEmpty {
            return bundleID.components(separatedBy: ".").last ?? bundleID
        }
        return "Process \(pid)"
    }
}
