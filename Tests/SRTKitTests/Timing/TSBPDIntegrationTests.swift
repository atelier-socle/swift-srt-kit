// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("TSBPD Integration Tests")
struct TSBPDIntegrationTests {
    @Test("100 packets at 10ms spacing, all on time, 0 drops")
    func allOnTime() {
        let latency: UInt64 = 120_000
        let tsbpd = TSBPDManager(
            configuration: .init(latencyMicroseconds: latency),
            baseTime: 1_000_000, firstTimestamp: 0
        )
        var dropper = TooLatePacketDrop()
        var deliveredCount = 0

        for i: UInt32 in 0..<100 {
            let senderTs = i * 10_000  // 10ms spacing
            let delivTime = tsbpd.deliveryTime(packetTimestamp: senderTs, driftCorrection: 0)
            // Simulate: currentTime = deliveryTime (packets arrive on time)
            let decision = dropper.check(deliveryTime: delivTime, currentTime: delivTime)
            if case .keep = decision {
                deliveredCount += 1
            }
        }

        #expect(deliveredCount == 100)
        #expect(dropper.totalDropped == 0)
    }

    @Test("Receiver clock 1% faster, drift corrected")
    func driftCorrected() {
        let latency: UInt64 = 120_000
        let tsbpd = TSBPDManager(
            configuration: .init(latencyMicroseconds: latency),
            baseTime: 1_000_000, firstTimestamp: 0
        )
        var drift = DriftManager(
            configuration: .init(
                windowSize: 50, maxCorrectionPerPeriod: 10_000, minSamplesForCorrection: 10
            ))

        // Send 50 packets, receiver clock is 1% faster
        for i: UInt32 in 1...50 {
            let senderTs = i * 10_000
            let prevSenderTs = (i - 1) * 10_000
            // Receiver clock runs 1% fast: gap is 10_100 instead of 10_000
            let receiveTime = UInt64(i) * 10_100 + 1_000_000
            let prevReceiveTime = UInt64(i - 1) * 10_100 + 1_000_000

            drift.addSample(
                senderTimestamp: senderTs, receiveTime: receiveTime,
                previousSenderTimestamp: prevSenderTs, previousReceiveTime: prevReceiveTime
            )
        }

        // Drift detected
        #expect(drift.hasEnoughSamples)
        #expect(drift.averageDrift == 100)  // +100µs per packet

        // Apply correction
        let correction = drift.applyCorrection()
        #expect(correction == 100)

        // With correction, delivery times are adjusted
        let adjustedTime = tsbpd.deliveryTime(
            packetTimestamp: 500_000, driftCorrection: drift.totalCorrection
        )
        let unadjustedTime = tsbpd.deliveryTime(
            packetTimestamp: 500_000, driftCorrection: 0
        )
        #expect(adjustedTime > unadjustedTime)
    }

    @Test("High latency 500ms, all packets buffered longer, still on time")
    func highLatency() {
        let latency: UInt64 = 500_000
        let tsbpd = TSBPDManager(
            configuration: .init(latencyMicroseconds: latency),
            baseTime: 1_000_000, firstTimestamp: 0
        )

        let delivTime = tsbpd.deliveryTime(packetTimestamp: 10_000, driftCorrection: 0)
        // Should be 1_000_000 + 10_000 + 500_000 = 1_510_000
        #expect(delivTime == 1_510_000)

        // At time 1_510_000, packet should be ready
        let decision = tsbpd.deliveryDecision(
            packetTimestamp: 10_000, currentTime: 1_510_000, driftCorrection: 0
        )
        #expect(decision == .deliver)
    }

    @Test("Burst loss + recovery: dropped counted, rest delivered")
    func burstLossRecovery() {
        let latency: UInt64 = 120_000
        let tsbpd = TSBPDManager(
            configuration: .init(latencyMicroseconds: latency),
            baseTime: 1_000_000, firstTimestamp: 0
        )
        var dropper = TooLatePacketDrop()
        var deliveredCount = 0
        var droppedCount = 0

        for i: UInt32 in 0..<20 {
            let senderTs = i * 10_000
            let delivTime = tsbpd.deliveryTime(packetTimestamp: senderTs, driftCorrection: 0)

            // Simulate: packets 5-9 arrive too late (300ms delay)
            let arrivalTime: UInt64
            if i >= 5 && i <= 9 {
                arrivalTime = delivTime + 300_000
            } else {
                arrivalTime = delivTime
            }

            let decision = dropper.check(deliveryTime: delivTime, currentTime: arrivalTime)
            switch decision {
            case .keep:
                deliveredCount += 1
            case .drop:
                droppedCount += 1
            }
        }

        #expect(deliveredCount == 15)
        #expect(droppedCount == 5)
    }

    @Test("Timestamp wrap-around mid-stream, delivery continues")
    func timestampWrapMidStream() {
        let latency: UInt64 = 120_000
        let startTs = UInt32.max - 50_000
        let tsbpd = TSBPDManager(
            configuration: .init(latencyMicroseconds: latency),
            baseTime: 1_000_000, firstTimestamp: startTs
        )

        // Before wrap
        let t1 = tsbpd.deliveryTime(packetTimestamp: startTs, driftCorrection: 0)
        // After wrap
        let t2 = tsbpd.deliveryTime(packetTimestamp: startTs &+ 10_000, driftCorrection: 0)

        // t2 should be 10_000 µs after t1
        #expect(t2 > t1)
        #expect(t2 - t1 == 10_000)
    }

    @Test("TSBPD disabled, all packets delivered immediately")
    func tsbpdDisabled() {
        let tsbpd = TSBPDManager(
            configuration: .init(enabled: false),
            baseTime: 1_000_000, firstTimestamp: 0
        )
        var deliveredCount = 0

        for i: UInt32 in 0..<50 {
            let decision = tsbpd.deliveryDecision(
                packetTimestamp: i * 10_000, currentTime: 0, driftCorrection: 0
            )
            if case .immediate = decision {
                deliveredCount += 1
            }
        }

        #expect(deliveredCount == 50)
    }

    @Test("Late packet detection: delayed packets are dropped")
    func latePacketDetection() {
        let latency: UInt64 = 120_000
        let tsbpd = TSBPDManager(
            configuration: .init(latencyMicroseconds: latency),
            baseTime: 1_000_000, firstTimestamp: 0
        )
        var dropper = TooLatePacketDrop()

        let senderTs: UInt32 = 50_000
        let delivTime = tsbpd.deliveryTime(packetTimestamp: senderTs, driftCorrection: 0)

        // Check at various times
        let earlyDecision = dropper.check(deliveryTime: delivTime, currentTime: delivTime - 10_000)
        #expect(earlyDecision == .keep)

        let onTimeDecision = dropper.check(deliveryTime: delivTime, currentTime: delivTime)
        #expect(onTimeDecision == .keep)

        let lateDecision = dropper.check(deliveryTime: delivTime, currentTime: delivTime + 5_000)
        if case .drop(let lateness) = lateDecision {
            #expect(lateness == 5_000)
        } else {
            #expect(Bool(false), "Expected drop")
        }
    }

    @Test("Simulated jitter keeps drift correction near zero")
    func jitterNearZeroDrift() {
        var drift = DriftManager(
            configuration: .init(
                windowSize: 50, maxCorrectionPerPeriod: 10_000, minSamplesForCorrection: 10
            ))

        // Alternating jitter: +2000 / -2000 µs
        for i: UInt32 in 1...40 {
            let jitter: Int64 = i % 2 == 0 ? 2000 : -2000
            let senderGap: UInt32 = 10_000
            let receiverGap = UInt64(Int64(senderGap) + jitter)

            drift.addSample(
                senderTimestamp: i * senderGap,
                receiveTime: UInt64(i - 1) * 10_000 + receiverGap + 1_000_000,
                previousSenderTimestamp: (i - 1) * senderGap,
                previousReceiveTime: UInt64(i - 1) * 10_000 + 1_000_000
            )
        }

        // Average drift should be near zero
        let correction = drift.calculateCorrection()
        #expect(correction >= -2000 && correction <= 2000)
    }
}
