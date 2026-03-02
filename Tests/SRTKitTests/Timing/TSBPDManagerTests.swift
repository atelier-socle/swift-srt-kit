// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("TSBPDManager Tests")
struct TSBPDManagerTests {
    // Helper: create a TSBPD manager with standard config
    private func makeTSBPD(
        latency: UInt64 = 120_000,
        enabled: Bool = true,
        tooLateDrop: Bool = true,
        baseTime: UInt64 = 1_000_000,
        firstTimestamp: UInt32 = 0
    ) -> TSBPDManager {
        TSBPDManager(
            configuration: .init(
                latencyMicroseconds: latency,
                enabled: enabled,
                tooLateDropEnabled: tooLateDrop
            ),
            baseTime: baseTime,
            firstTimestamp: firstTimestamp
        )
    }

    // MARK: - Delivery time calculation

    @Test("Basic delivery time: baseTime + packetTimestamp + latency")
    func basicDeliveryTime() {
        let tsbpd = makeTSBPD(latency: 120_000, baseTime: 1_000_000, firstTimestamp: 0)
        let time = tsbpd.deliveryTime(packetTimestamp: 10_000, driftCorrection: 0)
        // baseTime = 1_000_000 - 0 = 1_000_000
        // deliveryTime = 1_000_000 + 10_000 + 120_000 = 1_130_000
        #expect(time == 1_130_000)
    }

    @Test("Positive drift correction delays delivery")
    func positiveDriftCorrection() {
        let tsbpd = makeTSBPD(latency: 120_000, baseTime: 1_000_000, firstTimestamp: 0)
        let time = tsbpd.deliveryTime(packetTimestamp: 10_000, driftCorrection: 5_000)
        #expect(time == 1_135_000)
    }

    @Test("Negative drift correction accelerates delivery")
    func negativeDriftCorrection() {
        let tsbpd = makeTSBPD(latency: 120_000, baseTime: 1_000_000, firstTimestamp: 0)
        let time = tsbpd.deliveryTime(packetTimestamp: 10_000, driftCorrection: -5_000)
        #expect(time == 1_125_000)
    }

    @Test("Zero latency delivers at baseTime + packetTimestamp")
    func zeroLatency() {
        let tsbpd = makeTSBPD(latency: 0, baseTime: 1_000_000, firstTimestamp: 0)
        let time = tsbpd.deliveryTime(packetTimestamp: 50_000, driftCorrection: 0)
        #expect(time == 1_050_000)
    }

    @Test("Large latency 500ms offset correct")
    func largeLatency() {
        let tsbpd = makeTSBPD(latency: 500_000, baseTime: 1_000_000, firstTimestamp: 0)
        let time = tsbpd.deliveryTime(packetTimestamp: 10_000, driftCorrection: 0)
        #expect(time == 1_510_000)
    }

    @Test("firstTimestamp offsets baseTime correctly")
    func firstTimestampOffset() {
        // baseTime = 1_000_000, firstTimestamp = 500
        // internal baseTime = 1_000_000 - 500 = 999_500
        let tsbpd = makeTSBPD(latency: 120_000, baseTime: 1_000_000, firstTimestamp: 500)
        let time = tsbpd.deliveryTime(packetTimestamp: 500, driftCorrection: 0)
        // 999_500 + 500 + 120_000 = 1_120_000
        #expect(time == 1_120_000)
    }

    // MARK: - Delivery decision

    @Test("Packet ready when currentTime equals deliveryTime")
    func packetReady() {
        let tsbpd = makeTSBPD(latency: 120_000, baseTime: 1_000_000, firstTimestamp: 0)
        let delivTime = tsbpd.deliveryTime(packetTimestamp: 10_000, driftCorrection: 0)
        let decision = tsbpd.deliveryDecision(
            packetTimestamp: 10_000, currentTime: delivTime, driftCorrection: 0
        )
        #expect(decision == .deliver)
    }

    @Test("Packet early returns wait with correct microseconds")
    func packetEarly() {
        let tsbpd = makeTSBPD(latency: 120_000, baseTime: 1_000_000, firstTimestamp: 0)
        let decision = tsbpd.deliveryDecision(
            packetTimestamp: 10_000, currentTime: 1_100_000, driftCorrection: 0
        )
        // deliveryTime = 1_130_000, currentTime = 1_100_000 → wait 30_000
        #expect(decision == .wait(microseconds: 30_000))
    }

    @Test("Packet too late with drop enabled returns tooLate")
    func packetTooLate() {
        let tsbpd = makeTSBPD(latency: 120_000, baseTime: 1_000_000, firstTimestamp: 0)
        let decision = tsbpd.deliveryDecision(
            packetTimestamp: 10_000, currentTime: 1_200_000, driftCorrection: 0
        )
        #expect(decision == .tooLate)
    }

    @Test("Packet too late but drop disabled returns deliver")
    func packetTooLateDropDisabled() {
        let tsbpd = makeTSBPD(
            latency: 120_000, tooLateDrop: false, baseTime: 1_000_000, firstTimestamp: 0
        )
        let decision = tsbpd.deliveryDecision(
            packetTimestamp: 10_000, currentTime: 1_200_000, driftCorrection: 0
        )
        #expect(decision == .deliver)
    }

    @Test("TSBPD disabled returns immediate")
    func tsbpdDisabled() {
        let tsbpd = makeTSBPD(enabled: false, baseTime: 1_000_000, firstTimestamp: 0)
        let decision = tsbpd.deliveryDecision(
            packetTimestamp: 10_000, currentTime: 0, driftCorrection: 0
        )
        #expect(decision == .immediate)
    }

    // MARK: - Base time and packet spacing

    @Test("Increasing timestamps produce increasing delivery times")
    func increasingTimestamps() {
        let tsbpd = makeTSBPD(latency: 120_000, baseTime: 1_000_000, firstTimestamp: 0)
        let t1 = tsbpd.deliveryTime(packetTimestamp: 10_000, driftCorrection: 0)
        let t2 = tsbpd.deliveryTime(packetTimestamp: 20_000, driftCorrection: 0)
        let t3 = tsbpd.deliveryTime(packetTimestamp: 30_000, driftCorrection: 0)
        #expect(t2 > t1)
        #expect(t3 > t2)
    }

    @Test("Gap between delivery times matches sender gaps")
    func deliveryTimeGaps() {
        let tsbpd = makeTSBPD(latency: 120_000, baseTime: 1_000_000, firstTimestamp: 0)
        let t1 = tsbpd.deliveryTime(packetTimestamp: 10_000, driftCorrection: 0)
        let t2 = tsbpd.deliveryTime(packetTimestamp: 20_000, driftCorrection: 0)
        #expect(t2 - t1 == 10_000)
    }

    // MARK: - Configuration

    @Test("Default latency is 120ms")
    func defaultLatency() {
        let config = TSBPDManager.Configuration()
        #expect(config.latencyMicroseconds == 120_000)
    }

    @Test("Custom latency applied correctly")
    func customLatency() {
        let config = TSBPDManager.Configuration(latencyMicroseconds: 500_000)
        #expect(config.latencyMicroseconds == 500_000)
    }

    @Test("baseTime property is accessible")
    func baseTimeProperty() {
        let tsbpd = makeTSBPD(baseTime: 2_000_000, firstTimestamp: 1000)
        // Internal baseTime = 2_000_000 - 1000 = 1_999_000
        #expect(tsbpd.baseTime == 1_999_000)
    }
}
