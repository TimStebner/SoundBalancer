import Foundation

public final class Biquad: @unchecked Sendable {
    public enum FilterType: Sendable {
        case peaking
        case lowShelf
        case highShelf
        case lowPass
        case highPass
    }

    private var b0: Float = 1.0
    private var b1: Float = 0.0
    private var b2: Float = 0.0
    private var a1: Float = 0.0
    private var a2: Float = 0.0

    private var z1_L: Float = 0.0
    private var z2_L: Float = 0.0
    private var z1_R: Float = 0.0
    private var z2_R: Float = 0.0

    public init() {}

    public func reset() {
        z1_L = 0.0
        z2_L = 0.0
        z1_R = 0.0
        z2_R = 0.0
    }

    public func update(
        type: FilterType,
        frequency: Float,
        gainDB: Float,
        q: Float = 1.414,
        sampleRate: Float = 44100.0
    ) {
        let nyquist = sampleRate * 0.49
        let f0 = max(20.0, min(frequency, nyquist))
        let omega = 2.0 * Float.pi * f0 / sampleRate
        let sn = sin(omega)
        let cs = cos(omega)
        let alpha = sn / (2.0 * max(0.1, q))
        let A = pow(10.0, gainDB / 40.0)

        var b0_t: Float = 1.0
        var b1_t: Float = 0.0
        var b2_t: Float = 0.0
        var a0_t: Float = 1.0
        var a1_t: Float = 0.0
        var a2_t: Float = 0.0

        switch type {
        case .peaking:
            b0_t = 1.0 + alpha * A
            b1_t = -2.0 * cs
            b2_t = 1.0 - alpha * A
            a0_t = 1.0 + alpha / A
            a1_t = -2.0 * cs
            a2_t = 1.0 - alpha / A

        case .lowShelf:
            let twoSqrtAAlpha = 2.0 * sqrt(A) * alpha
            b0_t = A * ((A + 1.0) - (A - 1.0) * cs + twoSqrtAAlpha)
            b1_t = 2.0 * A * ((A - 1.0) - (A + 1.0) * cs)
            b2_t = A * ((A + 1.0) - (A - 1.0) * cs - twoSqrtAAlpha)
            a0_t = (A + 1.0) + (A - 1.0) * cs + twoSqrtAAlpha
            a1_t = -2.0 * ((A - 1.0) + (A + 1.0) * cs)
            a2_t = (A + 1.0) - (A - 1.0) * cs - twoSqrtAAlpha

        case .highShelf:
            let twoSqrtAAlpha = 2.0 * sqrt(A) * alpha
            b0_t = A * ((A + 1.0) + (A - 1.0) * cs + twoSqrtAAlpha)
            b1_t = -2.0 * A * ((A - 1.0) + (A + 1.0) * cs)
            b2_t = A * ((A + 1.0) - (A - 1.0) * cs - twoSqrtAAlpha)
            a0_t = (A + 1.0) - (A - 1.0) * cs + twoSqrtAAlpha
            a1_t = 2.0 * ((A - 1.0) - (A + 1.0) * cs)
            a2_t = (A + 1.0) - (A - 1.0) * cs - twoSqrtAAlpha

        case .lowPass:
            b0_t = (1.0 - cs) / 2.0
            b1_t = 1.0 - cs
            b2_t = (1.0 - cs) / 2.0
            a0_t = 1.0 + alpha
            a1_t = -2.0 * cs
            a2_t = 1.0 - alpha

        case .highPass:
            b0_t = (1.0 + cs) / 2.0
            b1_t = -(1.0 + cs)
            b2_t = (1.0 + cs) / 2.0
            a0_t = 1.0 + alpha
            a1_t = -2.0 * cs
            a2_t = 1.0 - alpha
        }

        let invA0 = 1.0 / a0_t
        b0 = b0_t * invA0
        b1 = b1_t * invA0
        b2 = b2_t * invA0
        a1 = a1_t * invA0
        a2 = a2_t * invA0
    }

    @inline(__always)
    public func processStereo(left: inout Float, right: inout Float) {
        let outL = b0 * left + z1_L
        z1_L = b1 * left - a1 * outL + z2_L
        z2_L = b2 * left - a2 * outL
        left = outL

        let outR = b0 * right + z1_R
        z1_R = b1 * right - a1 * outR + z2_R
        z2_R = b2 * right - a2 * outR
        right = outR
    }
}
