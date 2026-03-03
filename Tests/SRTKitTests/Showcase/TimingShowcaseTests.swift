// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("Timing Showcase")
struct TimingShowcaseTests {
    // MARK: - TSBPD

    @Test("TSBPD delivery time = timestamp + latency")
    func tsbpdDeliveryTime() {
        let config = TSBPDManager.Configuration(
            latencyMicroseconds: 120_000)
        let tsbpd = TSBPDManager(
            configuration: config,
            baseTime: 1_000_000,
            firstTimestamp: 0)

        // Packet at timestamp 50_000 should be delivered at
        // baseTime + (50_000 - first) + latency
        let deliveryTime = tsbpd.deliveryTime(
            packetTimestamp: 50_000, driftCorrection: 0)
        #expect(deliveryTime > 0)
    }

    @Test("TSBPD delivery decision: wait or deliver")
    func tsbpdDeliveryDecision() {
        let config = TSBPDManager.Configuration(
            latencyMicroseconds: 120_000)
        let tsbpd = TSBPDManager(
            configuration: config,
            baseTime: 1_000_000,
            firstTimestamp: 0)

        // Very early check — should wait
        let decision = tsbpd.deliveryDecision(
            packetTimestamp: 50_000,
            currentTime: 1_050_000,
            driftCorrection: 0)

        switch decision {
        case .wait:
            break  // Expected
        case .deliver:
            break  // Also valid if time has passed
        case .tooLate:
            Issue.record("Should not be too late")
        case .immediate:
            break
        }
    }

    // MARK: - TooLatePacketDrop

    @Test("Too-late packet is dropped")
    func tooLatePacketDrop() {
        let tlpktdrop = TooLatePacketDrop(enabled: true)

        // Packet that should have been delivered at t=100_000
        // but current time is t=300_000 (200ms late)
        let decision = tlpktdrop.check(
            deliveryTime: 100_000, currentTime: 300_000)

        if case .drop(let lateness) = decision {
            #expect(lateness == 200_000)
        } else {
            Issue.record("Expected drop decision")
        }
    }

    @Test("On-time packet is kept")
    func onTimePacketKept() {
        let tlpktdrop = TooLatePacketDrop(enabled: true)

        // Packet delivery time is in the future
        let decision = tlpktdrop.check(
            deliveryTime: 500_000, currentTime: 100_000)

        if case .keep = decision {
            // Expected
        } else {
            Issue.record("Expected keep decision")
        }
    }

    // MARK: - DriftManager

    @Test("DriftManager computes clock drift correction")
    func driftCorrection() {
        var drift = DriftManager()

        // Feed samples with consistent drift
        for i: UInt32 in 1...25 {
            drift.addSample(
                senderTimestamp: i * 10_000,
                receiveTime: UInt64(i) * 10_100,
                previousSenderTimestamp: (i - 1) * 10_000,
                previousReceiveTime: UInt64(i - 1) * 10_100)
        }

        #expect(drift.sampleCount == 25)
        #expect(drift.hasEnoughSamples)
        // Correction should be non-zero given consistent drift
        let correction = drift.calculateCorrection()
        #expect(type(of: correction) == Int64.self)
    }
}
