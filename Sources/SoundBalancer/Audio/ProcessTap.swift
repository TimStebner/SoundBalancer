import AudioToolbox
import CoreAudio
import Darwin
import Foundation
import os
import Synchronization

private final class ProcessTapMetrics: @unchecked Sendable {
    private let callbackCount = Atomic<UInt64>(0)
    private let totalCallbackInterval = Atomic<UInt64>(0)
    private let maxCallbackInterval = Atomic<UInt64>(0)
    private let totalRenderDuration = Atomic<UInt64>(0)
    private let maxRenderDuration = Atomic<UInt64>(0)
    private let inputFrames = Atomic<UInt64>(0)
    private let outputFrames = Atomic<UInt64>(0)
    private let lastCallbackTime = Atomic<UInt64>(0)

    func record(start: UInt64, end: UInt64, inputFrameCount: UInt64, outputFrameCount: UInt64) {
        callbackCount.wrappingAdd(1, ordering: .relaxed)
        inputFrames.wrappingAdd(inputFrameCount, ordering: .relaxed)
        outputFrames.wrappingAdd(outputFrameCount, ordering: .relaxed)

        let previousCallbackTime = lastCallbackTime.exchange(start, ordering: .relaxed)
        if previousCallbackTime > 0 {
            let interval = start &- previousCallbackTime
            totalCallbackInterval.wrappingAdd(interval, ordering: .relaxed)
            updateMaximum(interval, value: maxCallbackInterval)
        }

        let duration = end &- start
        totalRenderDuration.wrappingAdd(duration, ordering: .relaxed)
        updateMaximum(duration, value: maxRenderDuration)
    }

    func summary() -> String? {
        let callbacks = callbackCount.exchange(0, ordering: .relaxed)
        _ = lastCallbackTime.exchange(0, ordering: .relaxed)
        guard callbacks > 0 else { return nil }

        let callbackIntervals = totalCallbackInterval.exchange(0, ordering: .relaxed)
        let longestCallbackInterval = maxCallbackInterval.exchange(0, ordering: .relaxed)
        let renderDuration = totalRenderDuration.exchange(0, ordering: .relaxed)
        let longestRenderDuration = maxRenderDuration.exchange(0, ordering: .relaxed)
        let totalInputFrames = inputFrames.exchange(0, ordering: .relaxed)
        let totalOutputFrames = outputFrames.exchange(0, ordering: .relaxed)

        let intervals = callbacks - 1
        let averageIntervalMS = intervals > 0
            ? Double(AudioConvertHostTimeToNanos(callbackIntervals)) / Double(intervals) / 1_000_000
            : 0
        let averageRenderMS = Double(AudioConvertHostTimeToNanos(renderDuration)) / Double(callbacks) / 1_000_000
        let maximumIntervalMS = Double(AudioConvertHostTimeToNanos(longestCallbackInterval)) / 1_000_000
        let maximumRenderMS = Double(AudioConvertHostTimeToNanos(longestRenderDuration)) / 1_000_000

        return String(
            format: "callbacks=%llu avgInterval=%.2fms maxInterval=%.2fms avgRender=%.3fms maxRender=%.3fms inputFrames=%llu outputFrames=%llu",
            callbacks,
            averageIntervalMS,
            maximumIntervalMS,
            averageRenderMS,
            maximumRenderMS,
            totalInputFrames,
            totalOutputFrames
        )
    }

    private func updateMaximum(_ candidate: UInt64, value: borrowing Atomic<UInt64>) {
        var current = value.load(ordering: .relaxed)
        while candidate > current {
            let result = value.compareExchange(
                expected: current,
                desired: candidate,
                ordering: .relaxed
            )
            if result.exchanged { return }
            current = result.original
        }
    }
}

public final class ProcessTap: @unchecked Sendable {
    public static let aggregateUIDPrefix = "SoundBalancerAgg-"

    public let processObjectID: AudioObjectID
    private let outputDeviceUID: String
    private let driftCompensationEnabled: Bool
    private let queue: DispatchQueue

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?

    var aggregateDeviceID: AudioDeviceID { aggregateID }

    private let gainPtr: UnsafeMutablePointer<Float32>
    private let currentGainPtr: UnsafeMutablePointer<Float32>
    private let metrics = ProcessTapMetrics()

    public private(set) var isRunning = false
    public private(set) var lastError: String?

    private static let logger = Logger(subsystem: "com.timstebner.SoundBalancer", category: "ProcessTap")

    public init(
        processObjectID: AudioObjectID,
        outputDeviceUID: String,
        initialGain: Float32,
        driftCompensationEnabled: Bool
    ) {
        self.processObjectID = processObjectID
        self.outputDeviceUID = outputDeviceUID
        self.driftCompensationEnabled = driftCompensationEnabled
        self.queue = DispatchQueue(
            label: "com.timstebner.SoundBalancer.tap-io.\(processObjectID)",
            qos: .userInitiated
        )
        self.gainPtr = UnsafeMutablePointer<Float32>.allocate(capacity: 1)
        self.gainPtr.initialize(to: initialGain)
        self.currentGainPtr = UnsafeMutablePointer<Float32>.allocate(capacity: 1)
        self.currentGainPtr.initialize(to: initialGain)
    }

    deinit {
        cleanup()
        gainPtr.deinitialize(count: 1)
        gainPtr.deallocate()
        currentGainPtr.deinitialize(count: 1)
        currentGainPtr.deallocate()
    }

    public func setGain(_ gain: Float32) {
        gainPtr.pointee = gain
    }

    func diagnosticsSummary() -> String? {
        metrics.summary()
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
                    kAudioSubTapDriftCompensationKey: driftCompensationEnabled,
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

        let sampleRate: Float64 = CA.value(
            aggregateID,
            CA.address(kAudioDevicePropertyNominalSampleRate),
            fallback: 48000.0
        )
        let rampCoefficient = Float32(1.0 - exp(-1.0 / (max(sampleRate, 8000.0) * 0.030)))
        let gainPtr = self.gainPtr
        let currentGainPtr = self.currentGainPtr
        let metrics = self.metrics
        let ioBlock: AudioDeviceIOBlock = { _, inInputData, _, outOutputData, _ in
            let callbackStart = mach_absolute_time()
            let gain = gainPtr.pointee
            let input = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inInputData))
            let output = UnsafeMutableAudioBufferListPointer(outOutputData)
            ProcessTap.renderMix(
                from: input,
                to: output,
                gain: gain,
                currentGain: currentGainPtr,
                rampCoefficient: rampCoefficient
            )
            metrics.record(
                start: callbackStart,
                end: mach_absolute_time(),
                inputFrameCount: ProcessTap.frameCount(in: input),
                outputFrameCount: ProcessTap.frameCount(in: output)
            )
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

    private static func frameCount(in buffers: UnsafeMutableAudioBufferListPointer) -> UInt64 {
        guard buffers.count > 0 else { return 0 }
        let firstBuffer = buffers[0]
        let channels = max(1, Int(firstBuffer.mNumberChannels))
        let bytesPerFrame = channels * MemoryLayout<Float32>.size
        return UInt64(firstBuffer.mDataByteSize) / UInt64(bytesPerFrame)
    }

    private static func renderMix(
        from input: UnsafeMutableAudioBufferListPointer,
        to output: UnsafeMutableAudioBufferListPointer,
        gain: Float32,
        currentGain: UnsafeMutablePointer<Float32>,
        rampCoefficient: Float32
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

        var smoothedGain = currentGain.pointee
        if inChannels >= 2 && outChannels >= 2,
           let (srcL, sStrideL) = inChannelPtr(0),
           let (srcR, sStrideR) = inChannelPtr(1),
           let (dstL, dStrideL) = outChannelPtr(0),
           let (dstR, dStrideR) = outChannelPtr(1) {

            var f = 0
            while f < frames {
                smoothedGain += (gain - smoothedGain) * rampCoefficient
                dstL[f * dStrideL] = softLimit(srcL[f * sStrideL] * smoothedGain)
                dstR[f * dStrideR] = softLimit(srcR[f * sStrideR] * smoothedGain)
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
            var f = 0
            while f < frames {
                smoothedGain += (gain - smoothedGain) * rampCoefficient
                for co in 0..<outChannels {
                    guard let (dst, dStride) = outChannelPtr(co) else { continue }
                    let ci = co < inChannels ? co : inChannels - 1
                    if let (src, sStride) = inChannelPtr(ci) {
                        dst[f * dStride] = softLimit(src[f * sStride] * smoothedGain)
                    } else {
                        dst[f * dStride] = 0
                    }
                }
                f += 1
            }

            var t = frames
            while t < outFrames {
                for co in 0..<outChannels {
                    if let (dst, dStride) = outChannelPtr(co) {
                        dst[t * dStride] = 0
                    }
                }
                t += 1
            }
        }
        currentGain.pointee = smoothedGain
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
