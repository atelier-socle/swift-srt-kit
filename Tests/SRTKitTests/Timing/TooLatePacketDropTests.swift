// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("TooLatePacketDrop Tests")
struct TooLatePacketDropTests {
    @Test("On-time packet returns keep")
    func onTimeKeep() {
        let dropper = TooLatePacketDrop()
        let decision = dropper.check(deliveryTime: 1_000_000, currentTime: 999_000)
        #expect(decision == .keep)
    }

    @Test("Late packet returns drop with correct lateness")
    func lateDrop() {
        let dropper = TooLatePacketDrop()
        let decision = dropper.check(deliveryTime: 1_000_000, currentTime: 1_050_000)
        #expect(decision == .drop(lateness: 50_000))
    }

    @Test("Exactly on deadline returns keep")
    func exactlyOnDeadline() {
        let dropper = TooLatePacketDrop()
        let decision = dropper.check(deliveryTime: 1_000_000, currentTime: 1_000_000)
        #expect(decision == .keep)
    }

    @Test("Just past deadline returns drop with lateness 1")
    func justPastDeadline() {
        let dropper = TooLatePacketDrop()
        let decision = dropper.check(deliveryTime: 1_000_000, currentTime: 1_000_001)
        #expect(decision == .drop(lateness: 1))
    }

    @Test("Disabled always returns keep")
    func disabledKeep() {
        let dropper = TooLatePacketDrop(enabled: false)
        let decision = dropper.check(deliveryTime: 1_000_000, currentTime: 2_000_000)
        #expect(decision == .keep)
    }

    @Test("recordDrop increments totalDropped")
    func recordDropTotal() {
        var dropper = TooLatePacketDrop()
        _ = dropper.recordDrop(
            firstSequence: SequenceNumber(10),
            lastSequence: SequenceNumber(12),
            messageNumber: 1
        )
        #expect(dropper.totalDropped == 3)
    }

    @Test("recordDrop increments dropEventCount")
    func recordDropEventCount() {
        var dropper = TooLatePacketDrop()
        _ = dropper.recordDrop(
            firstSequence: SequenceNumber(10),
            lastSequence: SequenceNumber(10),
            messageNumber: 1
        )
        #expect(dropper.dropEventCount == 1)
    }

    @Test("recordDrop returns correct DropRange")
    func recordDropRange() {
        var dropper = TooLatePacketDrop()
        let range = dropper.recordDrop(
            firstSequence: SequenceNumber(5),
            lastSequence: SequenceNumber(8),
            messageNumber: 42
        )
        #expect(range.firstSequence == SequenceNumber(5))
        #expect(range.lastSequence == SequenceNumber(8))
        #expect(range.messageNumber == 42)
    }

    @Test("Multiple drops accumulate statistics")
    func multipleDrops() {
        var dropper = TooLatePacketDrop()
        _ = dropper.recordDrop(
            firstSequence: SequenceNumber(0),
            lastSequence: SequenceNumber(2),
            messageNumber: 1
        )
        _ = dropper.recordDrop(
            firstSequence: SequenceNumber(10),
            lastSequence: SequenceNumber(14),
            messageNumber: 2
        )
        #expect(dropper.totalDropped == 8)  // 3 + 5
        #expect(dropper.dropEventCount == 2)
    }

    @Test("resetStatistics clears counters")
    func resetStatistics() {
        var dropper = TooLatePacketDrop()
        _ = dropper.recordDrop(
            firstSequence: SequenceNumber(0),
            lastSequence: SequenceNumber(5),
            messageNumber: 1
        )
        dropper.resetStatistics()
        #expect(dropper.totalDropped == 0)
        #expect(dropper.dropEventCount == 0)
    }
}
