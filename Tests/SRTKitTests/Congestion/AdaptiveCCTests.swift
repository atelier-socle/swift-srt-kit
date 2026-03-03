// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("AdaptiveCC Tests")
struct AdaptiveCCTests {
    // MARK: - Helpers

    private func snapshot(
        rtt: UInt64 = 20_000,
        bandwidth: UInt64 = 5_000_000,
        sendRate: UInt64 = 4_000_000,
        inflight: Int = 50
    ) -> NetworkSnapshot {
        NetworkSnapshot(
            rttMicroseconds: rtt,
            estimatedBandwidthBps: bandwidth,
            sendRateBps: sendRate,
            packetsInFlight: inflight)
    }

    /// Feed consistent send rate samples to trigger realTime detection.
    private mutating func feedConsistentSamples(
        _ cc: inout AdaptiveCC, count: Int = 10
    ) {
        let snap = snapshot(sendRate: 4_000_000)
        for i in 0..<count {
            _ = cc.processEvent(
                .packetSent(
                    size: 1316,
                    sequenceNumber: UInt32(i),
                    timestamp: UInt64(i) * 10_000),
                snapshot: snap)
        }
    }

    /// Feed bursty send rate samples to trigger bulkTransfer detection.
    private mutating func feedBurstySamples(
        _ cc: inout AdaptiveCC, count: Int = 10
    ) {
        for i in 0..<count {
            // Alternate between very high and very low send rates
            let rate: UInt64 = i % 2 == 0 ? 10_000_000 : 500_000
            let snap = snapshot(sendRate: rate)
            _ = cc.processEvent(
                .packetSent(
                    size: 1316,
                    sequenceNumber: UInt32(i),
                    timestamp: UInt64(i) * 10_000),
                snapshot: snap)
        }
    }

    // MARK: - Detection

    @Test("Initial mode is .mixed")
    func initialModeMixed() {
        let cc = AdaptiveCC()
        #expect(cc.detectedMode == .mixed)
        #expect(cc.samplesCollected == 0)
    }

    @Test("Consistent send rate detected as .realTime")
    func consistentRateRealTime() {
        var cc = AdaptiveCC(
            configuration: .init(detectionSamples: 5))
        let snap = snapshot(sendRate: 4_000_000)
        for i in 0..<5 {
            _ = cc.processEvent(
                .packetSent(
                    size: 1316,
                    sequenceNumber: UInt32(i),
                    timestamp: UInt64(i) * 10_000),
                snapshot: snap)
        }
        #expect(cc.detectedMode == .realTime)
        #expect(cc.samplesCollected == 5)
    }

    @Test("Bursty send rate detected as .bulkTransfer")
    func burstyRateBulk() {
        var cc = AdaptiveCC(
            configuration: .init(
                detectionSamples: 5, realtimeVarianceThreshold: 0.2))
        for i in 0..<5 {
            let rate: UInt64 = i % 2 == 0 ? 10_000_000 : 500_000
            _ = cc.processEvent(
                .packetSent(
                    size: 1316,
                    sequenceNumber: UInt32(i),
                    timestamp: UInt64(i) * 10_000),
                snapshot: snapshot(sendRate: rate))
        }
        #expect(cc.detectedMode == .bulkTransfer)
    }

    @Test("samplesCollected tracks correctly")
    func samplesTracked() {
        var cc = AdaptiveCC()
        let snap = snapshot()
        for i in 0..<3 {
            _ = cc.processEvent(
                .packetSent(
                    size: 1316,
                    sequenceNumber: UInt32(i),
                    timestamp: UInt64(i) * 10_000),
                snapshot: snap)
        }
        #expect(cc.samplesCollected == 3)
    }

    // MARK: - Real-time behavior

    @Test("Real-time ACK: pacing period adjusted")
    func realtimeACKPacing() {
        var cc = AdaptiveCC(
            configuration: .init(detectionSamples: 3))
        // Force real-time mode
        let snap = snapshot(sendRate: 4_000_000)
        for i in 0..<3 {
            _ = cc.processEvent(
                .packetSent(
                    size: 1316,
                    sequenceNumber: UInt32(i),
                    timestamp: UInt64(i) * 10_000),
                snapshot: snap)
        }
        #expect(cc.detectedMode == .realTime)

        // ACK in real-time mode
        let ackSnap = snapshot(
            bandwidth: 5_000_000, sendRate: 4_000_000, inflight: 50)
        let decision = cc.processEvent(
            .ackReceived(
                ackSequence: 10,
                rttMicroseconds: 20_000,
                rttVarianceMicroseconds: 3_000,
                estimatedBandwidthBps: 5_000_000),
            snapshot: ackSnap)
        #expect(decision.sendingPeriodMicroseconds != nil)
        #expect(decision.congestionWindow != nil)
    }

    @Test("Real-time NAK: gentle reduction (12.5%)")
    func realtimeNAKGentle() {
        var cc = AdaptiveCC(
            configuration: .init(
                detectionSamples: 3, minimumWindow: 16))
        let snap = snapshot(sendRate: 4_000_000)
        for i in 0..<3 {
            _ = cc.processEvent(
                .packetSent(
                    size: 1316, sequenceNumber: UInt32(i),
                    timestamp: UInt64(i) * 10_000),
                snapshot: snap)
        }

        // Set window to a known value via ACK
        _ = cc.processEvent(
            .ackReceived(
                ackSequence: 5, rttMicroseconds: 20_000,
                rttVarianceMicroseconds: 3_000,
                estimatedBandwidthBps: 5_000_000),
            snapshot: snapshot(inflight: 100))
        let windowBefore = cc.congestionWindow

        // NAK in real-time mode
        let decision = cc.processEvent(
            .nakReceived(lossSequences: [10, 11]),
            snapshot: snap)
        // Reduced by 12.5% (7/8)
        let expected = max(16, windowBefore * 7 / 8)
        #expect(decision.congestionWindow == expected)
    }

    // MARK: - Bulk transfer behavior

    @Test("Bulk ACK: window grows by factor")
    func bulkACKWindowGrows() {
        var cc = AdaptiveCC(
            configuration: .init(
                detectionSamples: 3,
                realtimeVarianceThreshold: 0.2,
                windowGrowthFactor: 1.5,
                minimumWindow: 16))
        // Force bulk mode
        for i in 0..<3 {
            let rate: UInt64 = i % 2 == 0 ? 10_000_000 : 500_000
            _ = cc.processEvent(
                .packetSent(
                    size: 1316, sequenceNumber: UInt32(i),
                    timestamp: UInt64(i) * 10_000),
                snapshot: snapshot(sendRate: rate))
        }
        #expect(cc.detectedMode == .bulkTransfer)

        let windowBefore = cc.congestionWindow
        let decision = cc.processEvent(
            .ackReceived(
                ackSequence: 5, rttMicroseconds: 20_000,
                rttVarianceMicroseconds: 3_000,
                estimatedBandwidthBps: 5_000_000),
            snapshot: snapshot())

        // Window should grow by 1.5x
        let expected = min(8192, Int(Double(windowBefore) * 1.5))
        #expect(decision.congestionWindow == expected)
    }

    @Test("Bulk NAK: window halved")
    func bulkNAKHalved() {
        var cc = AdaptiveCC(
            configuration: .init(
                detectionSamples: 3,
                realtimeVarianceThreshold: 0.2,
                minimumWindow: 16))
        for i in 0..<3 {
            let rate: UInt64 = i % 2 == 0 ? 10_000_000 : 500_000
            _ = cc.processEvent(
                .packetSent(
                    size: 1316, sequenceNumber: UInt32(i),
                    timestamp: UInt64(i) * 10_000),
                snapshot: snapshot(sendRate: rate))
        }

        // Grow window first
        _ = cc.processEvent(
            .ackReceived(
                ackSequence: 5, rttMicroseconds: 20_000,
                rttVarianceMicroseconds: 3_000,
                estimatedBandwidthBps: 5_000_000),
            snapshot: snapshot())
        let windowBefore = cc.congestionWindow

        let decision = cc.processEvent(
            .nakReceived(lossSequences: [10]),
            snapshot: snapshot())
        let expected = max(16, windowBefore / 2)
        #expect(decision.congestionWindow == expected)
    }

}
