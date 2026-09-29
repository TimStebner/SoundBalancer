import Foundation
import Observation
import os

@Observable
public final class AudioPermission: @unchecked Sendable {
    public enum Status: Sendable {
        case unknown
        case denied
        case authorized
    }

    public private(set) var status: Status = .unknown

    nonisolated(unsafe) private static let service = "kTCCServiceAudioCapture" as CFString
    private static let logger = Logger(subsystem: "com.timstebner.SoundBalancer", category: "Permission")

    public init() {
        refresh()
    }

    public var isAuthorized: Bool {
        status == .authorized
    }

    public func refresh() {
        guard let preflight = Self.preflight else {
            status = .unknown
            return
        }
        let result = preflight(Self.service, nil)
        switch result {
        case 0:
            status = .authorized
        case 1:
            status = .denied
        default:
            status = .unknown
        }
    }

    public func request(completion: (@Sendable () -> Void)? = nil) {
        guard let requestFn = Self.request else {
            completion?()
            return
        }
        requestFn(Self.service, nil) { [weak self] granted in
            DispatchQueue.main.async {
                self?.status = granted ? .authorized : .denied
                completion?()
            }
        }
    }

    // MARK: - Dynamic TCC Symbols

    private typealias PreflightFn = @convention(c) (CFString, CFDictionary?) -> Int
    private typealias RequestFn = @convention(c) (CFString, CFDictionary?, @escaping (Bool) -> Void) -> Void

    nonisolated(unsafe) private static let handle: UnsafeMutableRawPointer? =
        dlopen("/System/Library/PrivateFrameworks/TCC.framework/Versions/A/TCC", RTLD_NOW)

    private static let preflight: PreflightFn? = {
        guard let handle, let sym = dlsym(handle, "TCCAccessPreflight") else { return nil }
        return unsafeBitCast(sym, to: PreflightFn.self)
    }()

    private static let request: RequestFn? = {
        guard let handle, let sym = dlsym(handle, "TCCAccessRequest") else { return nil }
        return unsafeBitCast(sym, to: RequestFn.self)
    }()
}
