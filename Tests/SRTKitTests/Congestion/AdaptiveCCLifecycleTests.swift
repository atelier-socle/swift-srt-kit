// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("AdaptiveCC Lifecycle Tests")
struct AdaptiveCCLifecycleTests {
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

    // MARK: - Lifecycle

    @Test("connectionEstablished initializes state")
    func connectionEstablished() {
        var cc = AdaptiveCC()
        let decision = cc.processEvent(
            .connectionEstablished(initialRTTMicroseconds: 20_000),
            snapshot: snapshot())
        #expect(decision.congestionWindow == 16)
    }

    @Test("connectionClosing returns noChange")
    func connectionClosing() {
        var cc = AdaptiveCC()
        let decision = cc.processEvent(
            .connectionClosing, snapshot: snapshot())
        #expect(decision == .noChange)
    }

    @Test("reset returns to initial state")
    func resetReturnsToInitial() {
        var cc = AdaptiveCC(
            configuration: .init(detectionSamples: 3))
        let snap = snapshot(sendRate: 4_000_000)
        for i in 0..<3 {
            _ = cc.processEvent(
                .packetSent(
                    size: 1316, sequenceNumber: UInt32(i),
                    timestamp: UInt64(i) * 10_000),
                snapshot: snap)
        }
        #expect(cc.detectedMode == .realTime)
        #expect(cc.samplesCollected == 3)

        cc.reset()
        #expect(cc.detectedMode == .mixed)
        #expect(cc.samplesCollected == 0)
        #expect(cc.modeSwitchCount == 0)
        #expect(cc.congestionWindow == 16)
    }

    @Test("modeSwitchCount tracks transitions")
    func modeSwitchCount() {
        var cc = AdaptiveCC(
            configuration: .init(detectionSamples: 3))

        // Start as mixed → realTime (1 switch)
        let snap = snapshot(sendRate: 4_000_000)
        for i in 0..<3 {
            _ = cc.processEvent(
                .packetSent(
                    size: 1316, sequenceNumber: UInt32(i),
                    timestamp: UInt64(i) * 10_000),
                snapshot: snap)
        }
        #expect(cc.modeSwitchCount == 1)
    }

    @Test("name is adaptive")
    func nameIsAdaptive() {
        let cc = AdaptiveCC()
        #expect(cc.name == "adaptive")
    }

    // MARK: - Configuration

    @Test("Default configuration has expected values")
    func defaultConfig() {
        let config = AdaptiveCC.Configuration.default
        #expect(config.detectionSamples == 10)
        #expect(config.realtimeVarianceThreshold == 0.2)
        #expect(config.windowGrowthFactor == 1.5)
        #expect(config.minimumWindow == 16)
        #expect(config.maximumWindow == 8192)
        #expect(config.pacingFloorMicroseconds == 1)
    }

    @Test("minimumWindow enforced")
    func minimumWindowEnforced() {
        var cc = AdaptiveCC(
            configuration: .init(
                detectionSamples: 3, minimumWindow: 32))
        // Force bulk mode and NAK to reduce window
        for i in 0..<3 {
            let rate: UInt64 = i % 2 == 0 ? 10_000_000 : 500_000
            _ = cc.processEvent(
                .packetSent(
                    size: 1316, sequenceNumber: UInt32(i),
                    timestamp: UInt64(i) * 10_000),
                snapshot: snapshot(sendRate: rate))
        }
        // Repeatedly NAK to reduce window
        for _ in 0..<20 {
            _ = cc.processEvent(
                .nakReceived(lossSequences: [1]),
                snapshot: snapshot())
        }
        #expect(cc.congestionWindow >= 32)
    }

    @Test("maximumWindow enforced")
    func maximumWindowEnforced() {
        var cc = AdaptiveCC(
            configuration: .init(
                detectionSamples: 3,
                realtimeVarianceThreshold: 0.2,
                windowGrowthFactor: 2.0,
                maximumWindow: 100))
        // Force bulk mode
        for i in 0..<3 {
            let rate: UInt64 = i % 2 == 0 ? 10_000_000 : 500_000
            _ = cc.processEvent(
                .packetSent(
                    size: 1316, sequenceNumber: UInt32(i),
                    timestamp: UInt64(i) * 10_000),
                snapshot: snapshot(sendRate: rate))
        }
        // Repeatedly ACK to grow window
        for _ in 0..<20 {
            _ = cc.processEvent(
                .ackReceived(
                    ackSequence: 5, rttMicroseconds: 20_000,
                    rttVarianceMicroseconds: 3_000,
                    estimatedBandwidthBps: 5_000_000),
                snapshot: snapshot())
        }
        #expect(cc.congestionWindow <= 100)
    }
}
