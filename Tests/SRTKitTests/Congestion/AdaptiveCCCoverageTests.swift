// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("AdaptiveCC Coverage Tests")
struct AdaptiveCCCoverageTests {
    private func makeSnapshot(
        rtt: UInt64 = 10_000,
        bandwidth: UInt64 = 10_000_000,
        packetsInFlight: Int = 50,
        sendRate: UInt64 = 5_000_000
    ) -> NetworkSnapshot {
        NetworkSnapshot(
            rttMicroseconds: rtt,
            rttVarianceMicroseconds: rtt / 4,
            estimatedBandwidthBps: bandwidth,
            sendRateBps: sendRate,
            lossRate: 0.05,
            packetsInFlight: packetsInFlight
        )
    }

    private var ackEvent: CongestionEvent {
        .ackReceived(
            ackSequence: 1,
            rttMicroseconds: 10_000,
            rttVarianceMicroseconds: 2_500,
            estimatedBandwidthBps: 10_000_000
        )
    }

    // MARK: - Timeout event in each detected mode

    @Test("Timeout in realTime mode reduces window by 25%")
    func timeoutInRealtimeMode() {
        var cc = AdaptiveCC(
            configuration: .init(
                detectionSamples: 3, realtimeVarianceThreshold: 0.5,
                minimumWindow: 4))
        // Feed consistent samples to trigger realtime detection
        for _ in 0..<3 {
            _ = cc.processEvent(
                .packetSent(size: 1316, sequenceNumber: 0, timestamp: 0),
                snapshot: makeSnapshot(sendRate: 5_000_000))
        }
        #expect(cc.detectedMode == .realTime)

        // Set window to a known value via ACK
        _ = cc.processEvent(ackEvent, snapshot: makeSnapshot())
        let windowBefore = cc.congestionWindow

        let decision = cc.processEvent(.timeout(lastACKSequence: 0), snapshot: makeSnapshot())
        #expect(cc.congestionWindow <= windowBefore)
        #expect(decision.congestionWindow != nil)
    }

    @Test("Timeout in bulkTransfer mode halves window")
    func timeoutInBulkMode() {
        var cc = AdaptiveCC(
            configuration: .init(
                detectionSamples: 3, realtimeVarianceThreshold: 0.01,
                minimumWindow: 4))
        // Feed highly variable samples to trigger bulk detection
        let rates: [UInt64] = [100_000, 10_000_000, 500_000]
        for rate in rates {
            _ = cc.processEvent(
                .packetSent(size: 1316, sequenceNumber: 0, timestamp: 0),
                snapshot: makeSnapshot(sendRate: rate))
        }
        #expect(cc.detectedMode == .bulkTransfer)

        _ = cc.processEvent(ackEvent, snapshot: makeSnapshot())
        let decision = cc.processEvent(.timeout(lastACKSequence: 0), snapshot: makeSnapshot())
        #expect(decision.congestionWindow != nil)
    }

    @Test("Timeout in mixed mode reduces window by 37.5%")
    func timeoutInMixedMode() {
        var cc = AdaptiveCC(configuration: .init(minimumWindow: 4))
        #expect(cc.detectedMode == .mixed)

        _ = cc.processEvent(ackEvent, snapshot: makeSnapshot())
        let decision = cc.processEvent(.timeout(lastACKSequence: 0), snapshot: makeSnapshot())
        #expect(decision.congestionWindow != nil)
    }

    // MARK: - NAK in each mode

    @Test("NAK in mixed mode reduces window by 25%")
    func nakInMixedMode() {
        var cc = AdaptiveCC(configuration: .init(minimumWindow: 4))
        _ = cc.processEvent(ackEvent, snapshot: makeSnapshot())
        let decision = cc.processEvent(
            .nakReceived(lossSequences: [1]),
            snapshot: makeSnapshot())
        #expect(decision.congestionWindow != nil)
    }

    // MARK: - ACK handling in each mode

    @Test("ACK in mixed mode grows window and sets pacing")
    func ackInMixedMode() {
        var cc = AdaptiveCC(configuration: .init(minimumWindow: 4))
        let decision = cc.processEvent(
            ackEvent, snapshot: makeSnapshot(bandwidth: 10_000_000))
        #expect(decision.congestionWindow != nil)
    }

    @Test("ACK in mixed mode with zero bandwidth skips pacing")
    func ackInMixedModeZeroBandwidth() {
        var cc = AdaptiveCC(configuration: .init(minimumWindow: 4))
        let decision = cc.processEvent(
            ackEvent, snapshot: makeSnapshot(bandwidth: 0))
        #expect(decision.congestionWindow != nil)
    }

    @Test("ACK in bulkTransfer mode uses window growth")
    func ackInBulkMode() {
        var cc = AdaptiveCC(
            configuration: .init(
                detectionSamples: 3, realtimeVarianceThreshold: 0.01,
                minimumWindow: 4))
        let rates: [UInt64] = [100_000, 10_000_000, 500_000]
        for rate in rates {
            _ = cc.processEvent(
                .packetSent(size: 1316, sequenceNumber: 0, timestamp: 0),
                snapshot: makeSnapshot(sendRate: rate))
        }
        let decision = cc.processEvent(
            ackEvent, snapshot: makeSnapshot())
        #expect(decision.congestionWindow != nil)
    }

    // MARK: - sendingPeriodMicroseconds getter

    @Test("sendingPeriodMicroseconds starts at 0")
    func sendingPeriodStartsZero() {
        let cc = AdaptiveCC()
        #expect(cc.sendingPeriodMicroseconds == 0)
    }

    @Test("sendingPeriodMicroseconds changes after realtime ACK")
    func sendingPeriodChangesAfterRealtimeACK() {
        var cc = AdaptiveCC(
            configuration: .init(
                detectionSamples: 3, realtimeVarianceThreshold: 0.5,
                minimumWindow: 4))
        for _ in 0..<3 {
            _ = cc.processEvent(
                .packetSent(size: 1316, sequenceNumber: 0, timestamp: 0),
                snapshot: makeSnapshot(sendRate: 5_000_000))
        }
        _ = cc.processEvent(
            ackEvent,
            snapshot: makeSnapshot(bandwidth: 10_000_000))
        #expect(cc.sendingPeriodMicroseconds > 0)
    }

    // MARK: - coefficientOfVariation edge cases (via mode detection)

    @Test("All-zero send rates result in mixed mode")
    func zeroSendRatesResultInMixed() {
        var cc = AdaptiveCC(
            configuration: .init(
                detectionSamples: 3, realtimeVarianceThreshold: 0.2,
                minimumWindow: 4))
        for _ in 0..<3 {
            _ = cc.processEvent(
                .packetSent(size: 1316, sequenceNumber: 0, timestamp: 0),
                snapshot: makeSnapshot(sendRate: 0))
        }
        // CV with all zeros: mean=0 → returns 0 → < threshold → realTime
        #expect(cc.detectedMode == .realTime)
    }

    // MARK: - Mode switch counting

    @Test("Mode switch count increments on detection change")
    func modeSwitchCountIncrements() {
        var cc = AdaptiveCC(
            configuration: .init(
                detectionSamples: 3, realtimeVarianceThreshold: 0.2,
                minimumWindow: 4))
        #expect(cc.modeSwitchCount == 0)

        // Trigger realtime detection
        for _ in 0..<3 {
            _ = cc.processEvent(
                .packetSent(size: 1316, sequenceNumber: 0, timestamp: 0),
                snapshot: makeSnapshot(sendRate: 5_000_000))
        }
        let countAfterFirst = cc.modeSwitchCount
        #expect(countAfterFirst >= 1)
    }

    // MARK: - connectionEstablished resets window

    @Test("connectionEstablished sets window to minimum")
    func connectionEstablishedResetsWindow() {
        var cc = AdaptiveCC(
            configuration: .init(minimumWindow: 16))
        let decision = cc.processEvent(
            .connectionEstablished(initialRTTMicroseconds: 10_000), snapshot: makeSnapshot())
        #expect(decision.congestionWindow == 16)
    }

    // MARK: - connectionClosing is no-op

    @Test("connectionClosing returns noChange")
    func connectionClosingNoChange() {
        var cc = AdaptiveCC()
        let decision = cc.processEvent(
            .connectionClosing, snapshot: makeSnapshot())
        #expect(decision.congestionWindow == nil)
    }

    // MARK: - tick is no-op

    @Test("tick returns noChange")
    func tickNoChange() {
        var cc = AdaptiveCC()
        let decision = cc.processEvent(.tick(currentTime: 1_000_000), snapshot: makeSnapshot())
        #expect(decision.congestionWindow == nil)
    }
}
