// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("CC Plugin Showcase")
struct CCPluginShowcaseTests {
    // MARK: - Dispatcher

    @Test("Dispatcher routes events and collects decisions")
    func dispatcherRouting() {
        var dispatcher = CongestionControllerDispatcher(
            plugin: AdaptiveCC())
        #expect(dispatcher.activePluginName == "adaptive")

        // Connection established
        let decision = dispatcher.dispatch(
            event: .connectionEstablished(
                initialRTTMicroseconds: 20_000),
            snapshot: NetworkSnapshot())
        #expect(decision.congestionWindow != nil)
        #expect(dispatcher.eventsDispatched == 1)
    }

    @Test("Dispatcher hot-swap plugin at runtime")
    func dispatcherHotSwap() {
        var dispatcher = CongestionControllerDispatcher(
            plugin: AdaptiveCC())
        #expect(dispatcher.activePluginName == "adaptive")

        // Dispatch some events
        _ = dispatcher.dispatch(
            event: .tick(currentTime: 0),
            snapshot: NetworkSnapshot())
        #expect(dispatcher.eventsDispatched == 1)

        // Hot-swap to a fresh AdaptiveCC
        let newCC = AdaptiveCC(
            configuration: .init(detectionSamples: 5))
        dispatcher.swapPlugin(newCC)
        #expect(dispatcher.activePluginName == "adaptive")

        // Events go to new plugin
        _ = dispatcher.dispatch(
            event: .tick(currentTime: 10_000),
            snapshot: NetworkSnapshot())
        #expect(dispatcher.eventsDispatched == 2)
    }

    @Test("Dispatcher tracks recent events capped at 100")
    func recentEventsCapped() {
        var dispatcher = CongestionControllerDispatcher(
            plugin: AdaptiveCC())
        for i: UInt64 in 0..<120 {
            _ = dispatcher.dispatch(
                event: .tick(currentTime: i * 10_000),
                snapshot: NetworkSnapshot())
        }
        #expect(dispatcher.recentEvents.count == 100)
        #expect(dispatcher.eventsDispatched == 120)
    }

    // MARK: - AdaptiveCC

    @Test("AdaptiveCC detects real-time traffic pattern")
    func adaptiveCCRealTime() {
        var cc = AdaptiveCC(
            configuration: .init(detectionSamples: 5))

        // Consistent send rate → realTime detection
        let snap = NetworkSnapshot(sendRateBps: 4_000_000)
        for i in 0..<5 {
            _ = cc.processEvent(
                .packetSent(
                    size: 1316,
                    sequenceNumber: UInt32(i),
                    timestamp: UInt64(i) * 10_000),
                snapshot: snap)
        }
        #expect(cc.detectedMode == .realTime)
        #expect(cc.modeSwitchCount == 1)
    }

    @Test("AdaptiveCC detects bulk transfer pattern")
    func adaptiveCCBulk() {
        var cc = AdaptiveCC(
            configuration: .init(
                detectionSamples: 5,
                realtimeVarianceThreshold: 0.2))

        // Bursty send rate → bulkTransfer detection
        for i in 0..<5 {
            let rate: UInt64 = i % 2 == 0 ? 10_000_000 : 500_000
            let snap = NetworkSnapshot(sendRateBps: rate)
            _ = cc.processEvent(
                .packetSent(
                    size: 1316,
                    sequenceNumber: UInt32(i),
                    timestamp: UInt64(i) * 10_000),
                snapshot: snap)
        }
        #expect(cc.detectedMode == .bulkTransfer)
    }

    @Test("AdaptiveCC reset clears all state")
    func adaptiveCCReset() {
        var cc = AdaptiveCC(
            configuration: .init(detectionSamples: 3))

        // Get into realTime mode
        let snap = NetworkSnapshot(sendRateBps: 4_000_000)
        for i in 0..<3 {
            _ = cc.processEvent(
                .packetSent(
                    size: 1316,
                    sequenceNumber: UInt32(i),
                    timestamp: UInt64(i) * 10_000),
                snapshot: snap)
        }
        #expect(cc.detectedMode == .realTime)

        cc.reset()
        #expect(cc.detectedMode == .mixed)
        #expect(cc.samplesCollected == 0)
        #expect(cc.modeSwitchCount == 0)
    }
}
