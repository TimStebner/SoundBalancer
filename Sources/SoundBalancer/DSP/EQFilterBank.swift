import Foundation
import os

public final class EQFilterBank: @unchecked Sendable {
    public static let bandCount = 10
    private let filters: [Biquad]
    private var sampleRate: Float = 44100.0
    private var currentGains: [Float] = [Float](repeating: 0.0, count: bandCount)
    private var isBypassed: Bool = false
    private let lock = os_unfair_lock_t.allocate(capacity: 1)

    public init() {
        self.filters = (0..<Self.bandCount).map { _ in Biquad() }
        lock.initialize(to: os_unfair_lock())
        updateCoefficients()
    }

    deinit {
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    public func setSampleRate(_ rate: Float) {
        os_unfair_lock_lock(lock)
        self.sampleRate = max(8000.0, rate)
        updateCoefficients()
        os_unfair_lock_unlock(lock)
    }

    public func setGains(_ gains: [Float]) {
        os_unfair_lock_lock(lock)
        for i in 0..<min(Self.bandCount, gains.count) {
            currentGains[i] = max(-12.0, min(12.0, gains[i]))
        }
        updateCoefficients()
        os_unfair_lock_unlock(lock)
    }

    public func setBypassed(_ bypassed: Bool) {
        os_unfair_lock_lock(lock)
        self.isBypassed = bypassed
        os_unfair_lock_unlock(lock)
    }

    private func updateCoefficients() {
        let freqs = EQPreset.standardFrequencies
        for i in 0..<Self.bandCount {
            let freq = freqs[i]
            let gain = currentGains[i]
            let type: Biquad.FilterType
            if i == 0 {
                type = .lowShelf
            } else if i == Self.bandCount - 1 {
                type = .highShelf
            } else {
                type = .peaking
            }
            filters[i].update(
                type: type,
                frequency: freq,
                gainDB: gain,
                q: 1.414,
                sampleRate: sampleRate
            )
        }
    }

    public func reset() {
        os_unfair_lock_lock(lock)
        for f in filters { f.reset() }
        os_unfair_lock_unlock(lock)
    }

    @inline(__always)
    public func processSample(left: inout Float, right: inout Float) {
        if isBypassed { return }
        for f in filters {
            f.processStereo(left: &left, right: &right)
        }
    }
}
