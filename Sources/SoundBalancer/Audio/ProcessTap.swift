import AudioToolbox
import CoreAudio
import Foundation
import os

public final class ProcessTap: @unchecked Sendable {
    public static let aggregateUIDPrefix = "SoundBalancerAgg-"

    public let processObjectID: AudioObjectID
    private let outputDeviceUID: String
    private let queue: DispatchQueue

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?

    private let gainPtr: UnsafeMutablePointer<Float32>
    private let filterBank: EQFilterBank

    public private(set) var isRunning = false
    public private(set) var lastError: String?

    private static let logger = Logger(subsystem: "com.timstebner.SoundBalancer", category: "ProcessTap")

    public init(
        processObjectID: AudioObjectID,
        outputDeviceUID: String,
        initialGain: Float32,
        filterBank: EQFilterBank,
        queue: DispatchQueue
    ) {
        self.processObjectID = processObjectID
        self.outputDeviceUID = outputDeviceUID
        self.queue = queue
        self.filterBank = filterBank
        self.gainPtr = UnsafeMutablePointer<Float32>.allocate(capacity: 1)
        self.gainPtr.initialize(to: initialGain)
    }

    deinit {
        cleanup()
        gainPtr.deinitialize(count: 1)
        gainPtr.deallocate()
    }

    public func setGain(_ gain: Float32) {
        gainPtr.pointee = gain
    }

    @discardableResult
    public func start() -> Bool {
        guard !isRunning else { return true }

        let description = CATapDescription(stereoMixdownOfProcesses: [processObjectID])
        description.uuid = UUID()
        description.muteBehavior = .mutedWhenTapped
        description.name = "SoundBalancerTap-\(processObjectID)"

        var newTapID = AudioObjectID(kAudioObjectUnknown)
        var status = AudioHardwareCreateProcessTap(description, &newTapID)
        guard status == noErr, newTapID != kAudioObjectUnknown else {
            lastError = "AudioHardwareCreateProcessTap failed with status: \(status)"
            Self.logger.error("Failed to create process tap for \(self.processObjectID): \(status)")
            return false
        }
        tapID = newTapID

        let aggregateUID = Self.aggregateUIDPrefix + UUID().uuidString
        let aggregateConfig: [String: Any] = [
            kAudioAggregateDeviceNameKey: "SoundBalancer-\(processObjectID)",
            kAudioAggregateDeviceUIDKey: aggregateUID,
            kAudioAggregateDeviceMainSubDeviceKey: outputDeviceUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [
                [kAudioSubDeviceUIDKey: outputDeviceUID]
            ],
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapDriftCompensationKey: true,
                    kAudioSubTapUIDKey: description.uuid.uuidString
                ]
            ]
        ]

        var newAggregate = AudioObjectID(kAudioObjectUnknown)
        status = AudioHardwareCreateAggregateDevice(aggregateConfig as CFDictionary, &newAggregate)
        guard status == noErr, newAggregate != kAudioObjectUnknown else {
            lastError = "AudioHardwareCreateAggregateDevice failed with status: \(status)"
            Self.logger.error("Failed to create aggregate device: \(status)")
            cleanup()
            return false
        }
        aggregateID = newAggregate

        let gainPtr = self.gainPtr
        let filterBank = self.filterBank
        let ioBlock: AudioDeviceIOBlock = { _, inInputData, _, outOutputData, _ in
            let gain = gainPtr.pointee
            let input = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inInputData))
            let output = UnsafeMutableAudioBufferListPointer(outOutputData)
            ProcessTap.renderMix(from: input, to: output, gain: gain, filterBank: filterBank)
        }

        var newProcID: AudioDeviceIOProcID?
        status = AudioDeviceCreateIOProcIDWithBlock(&newProcID, aggregateID, queue, ioBlock)
        guard status == noErr, let newProcID else {
            lastError = "AudioDeviceCreateIOProcIDWithBlock failed with status: \(status)"
            cleanup()
            return false
        }
        ioProcID = newProcID

        status = AudioDeviceStart(aggregateID, newProcID)
        guard status == noErr else {
            lastError = "AudioDeviceStart failed with status: \(status)"
            cleanup()
            return false
        }

        isRunning = true
        return true
    }

    public func stop() {
        cleanup()
    }

    @inline(__always)
    private static func softLimit(_ x: Float32) -> Float32 {
        let threshold: Float32 = 0.85
        let headroom: Float32 = 0.15
        if x > threshold {
            return threshold + headroom * tanhf((x - threshold) / headroom)
        } else if x < -threshold {
            return -threshold + headroom * tanhf((x + threshold) / headroom)
        }
        return x
    }

    private static func renderMix(
        from input: UnsafeMutableAudioBufferListPointer,
        to output: UnsafeMutableAudioBufferListPointer,
        gain: Float32,
        filterBank: EQFilterBank
    ) {
        guard output.count > 0 else { return }

        let outInterleaved = output.count == 1 && output[0].mNumberChannels > 1
        let outChannels = outInterleaved ? Int(output[0].mNumberChannels) : output.count
        let outFrames = outInterleaved
            ? Int(output[0].mDataByteSize) / (Int(output[0].mNumberChannels) * MemoryLayout<Float32>.size)
            : Int(output[0].mDataByteSize) / MemoryLayout<Float32>.size

        guard input.count > 0, input[0].mData != nil else {
            for buffer in output {
                if let dst = buffer.mData { memset(dst, 0, Int(buffer.mDataByteSize)) }
            }
            return
        }

        let inInterleaved = input.count == 1 && input[0].mNumberChannels > 1
        let inChannels = inInterleaved ? Int(input[0].mNumberChannels) : input.count
        let inFrames = inInterleaved
            ? Int(input[0].mDataByteSize) / (Int(input[0].mNumberChannels) * MemoryLayout<Float32>.size)
            : Int(input[0].mDataByteSize) / MemoryLayout<Float32>.size

        let frames = min(inFrames, outFrames)

        func inChannelPtr(_ ch: Int) -> (UnsafeMutablePointer<Float32>, Int)? {
            if inInterleaved {
                guard let base = input[0].mData?.assumingMemoryBound(to: Float32.self) else { return nil }
                return (base + ch, inChannels)
            } else {
                guard ch < input.count, let base = input[ch].mData?.assumingMemoryBound(to: Float32.self) else { return nil }
                return (base, 1)
            }
        }

        func outChannelPtr(_ ch: Int) -> (UnsafeMutablePointer<Float32>, Int)? {
            if outInterleaved {
                guard let base = output[0].mData?.assumingMemoryBound(to: Float32.self) else { return nil }
                return (base + ch, outChannels)
            } else {
                guard ch < output.count, let base = output[ch].mData?.assumingMemoryBound(to: Float32.self) else { return nil }
                return (base, 1)
            }
        }

        if inChannels >= 2 && outChannels >= 2,
           let (srcL, sStrideL) = inChannelPtr(0),
           let (srcR, sStrideR) = inChannelPtr(1),
           let (dstL, dStrideL) = outChannelPtr(0),
           let (dstR, dStrideR) = outChannelPtr(1) {

            var f = 0
            while f < frames {
                var sL = srcL[f * sStrideL] * gain
                var sR = srcR[f * sStrideR] * gain

                filterBank.processSample(left: &sL, right: &sR)

                dstL[f * dStrideL] = softLimit(sL)
                dstR[f * dStrideR] = softLimit(sR)
                f += 1
            }

            var t = frames
            while t < outFrames {
                dstL[t * dStrideL] = 0
                dstR[t * dStrideR] = 0
                t += 1
            }

            if outChannels > 2 {
                for co in 2..<outChannels {
                    if let (extraDst, extraStride) = outChannelPtr(co) {
                        for ef in 0..<outFrames {
                            extraDst[ef * extraStride] = 0
                        }
                    }
                }
            }
        } else {
            for co in 0..<outChannels {
                guard let (dst, dStride) = outChannelPtr(co) else { continue }
                let ci = co < inChannels ? co : inChannels - 1
                if let (src, sStride) = inChannelPtr(ci) {
                    var f = 0
                    while f < frames {
                        dst[f * dStride] = softLimit(src[f * sStride] * gain)
                        f += 1
                    }
                    var t = frames
                    while t < outFrames { dst[t * dStride] = 0; t += 1 }
                } else {
                    var t = 0
                    while t < outFrames { dst[t * dStride] = 0; t += 1 }
                }
            }
        }
    }

    private func cleanup() {
        if aggregateID != kAudioObjectUnknown {
            if let ioProcID {
                AudioDeviceStop(aggregateID, ioProcID)
                AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
                self.ioProcID = nil
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
        isRunning = false
    }
}
