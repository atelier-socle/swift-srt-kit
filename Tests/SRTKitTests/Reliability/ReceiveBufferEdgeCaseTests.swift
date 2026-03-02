// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("ReceiveBuffer Edge Case Tests")
struct ReceiveBufferEdgeCaseTests {
    private func makePacket(
        seq: UInt32,
        payload: [UInt8] = [0xCD]
    ) -> ReceiveBuffer.ReceivedPacket {
        ReceiveBuffer.ReceivedPacket(
            sequenceNumber: SequenceNumber(seq),
            payload: payload
        )
    }

    // MARK: - Drop

    @Test("drop(upTo:) advances nextExpected")
    func dropAdvancesExpected() {
        var buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(0))
        buf.drop(upTo: SequenceNumber(5))
        #expect(buf.nextExpected == SequenceNumber(6))
    }

    @Test("drop(upTo:) removes buffered packets in dropped range")
    func dropRemovesBuffered() {
        var buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(0))
        _ = buf.insert(makePacket(seq: 2))
        _ = buf.insert(makePacket(seq: 3))
        _ = buf.insert(makePacket(seq: 5))
        buf.drop(upTo: SequenceNumber(3))
        #expect(buf.nextExpected == SequenceNumber(4))
        #expect(buf.bufferedCount == 1)  // only seq 5 remains
    }

    @Test("After drop previously-buffered packet becomes tooOld")
    func dropMakesBufferedTooOld() {
        var buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(0))
        buf.drop(upTo: SequenceNumber(10))
        let result = buf.insert(makePacket(seq: 5))
        #expect(result == .tooOld)
    }

    @Test("removeAll clears all buffered packets")
    func removeAll() {
        var buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(0))
        _ = buf.insert(makePacket(seq: 5))
        _ = buf.insert(makePacket(seq: 10))
        buf.removeAll()
        #expect(buf.bufferedCount == 0)
        #expect(!buf.hasGaps)
    }

    // MARK: - Wrap-around

    @Test("Wrap-around in sequence numbers handled correctly")
    func wrapAround() {
        let nearMax = SequenceNumber.max - 2
        var buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(nearMax))
        // Insert near-max, max, 0 in order
        let r1 = buf.insert(makePacket(seq: nearMax))
        if case .deliverable = r1 {
        } else {
            #expect(Bool(false), "Expected deliverable for nearMax")
        }
        let r2 = buf.insert(makePacket(seq: nearMax + 1))
        if case .deliverable = r2 {
        } else {
            #expect(Bool(false), "Expected deliverable for max-1")
        }
        let r3 = buf.insert(makePacket(seq: nearMax + 2))  // == max
        if case .deliverable = r3 {
        } else {
            #expect(Bool(false), "Expected deliverable for max")
        }
        let r4 = buf.insert(makePacket(seq: 0))  // wraps
        if case .deliverable = r4 {
        } else {
            #expect(Bool(false), "Expected deliverable for 0")
        }
        #expect(buf.nextExpected == SequenceNumber(1))
    }

    @Test("Gap detection across wrap-around boundary")
    func gapAcrossWrap() {
        let nearMax = SequenceNumber.max - 1
        var buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(nearMax))
        // Insert seq 1 (skipping nearMax, max, 0)
        _ = buf.insert(makePacket(seq: 1))
        let missing = buf.missingSequenceNumbers
        #expect(missing.contains(SequenceNumber(nearMax)))
        #expect(missing.contains(SequenceNumber(SequenceNumber.max)))
        #expect(missing.contains(SequenceNumber(0)))
    }

    // MARK: - Partial gap fill

    @Test("Partial gap fill delivers only contiguous chain")
    func partialGapFill() {
        var buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(0))
        // Buffer 2, 3, 5, 6
        _ = buf.insert(makePacket(seq: 2))
        _ = buf.insert(makePacket(seq: 3))
        _ = buf.insert(makePacket(seq: 5))
        _ = buf.insert(makePacket(seq: 6))
        // Fill gap at 1 (still missing 0)
        _ = buf.insert(makePacket(seq: 1))
        #expect(buf.bufferedCount == 5)  // 1,2,3,5,6 all buffered since 0 is missing
        // Now fill 0
        let result = buf.insert(makePacket(seq: 0))
        if case .deliverable(let packets) = result {
            // 0,1,2,3 delivered (then gap at 4)
            #expect(packets.count == 4)
        } else {
            #expect(Bool(false), "Expected deliverable")
        }
        // 5,6 still buffered waiting for 4
        #expect(buf.bufferedCount == 2)
    }

    @Test("Insert into empty buffer with high initial sequence")
    func highInitialSequence() {
        var buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(1_000_000))
        let result = buf.insert(makePacket(seq: 1_000_000))
        if case .deliverable(let packets) = result {
            #expect(packets.count == 1)
        } else {
            #expect(Bool(false), "Expected deliverable")
        }
    }
}
