// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("ReceiveBuffer Tests")
struct ReceiveBufferTests {
    private func makePacket(
        seq: UInt32,
        payload: [UInt8] = [0xCD]
    ) -> ReceiveBuffer.ReceivedPacket {
        ReceiveBuffer.ReceivedPacket(
            sequenceNumber: SequenceNumber(seq),
            payload: payload
        )
    }

    // MARK: - In-order delivery

    @Test("Insert next expected returns deliverable")
    func insertNextExpected() {
        var buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(0))
        let result = buf.insert(makePacket(seq: 0))
        if case .deliverable(let packets) = result {
            #expect(packets.count == 1)
            #expect(packets[0].sequenceNumber == SequenceNumber(0))
        } else {
            #expect(Bool(false), "Expected deliverable")
        }
    }

    @Test("Insert next expected with buffered successors delivers chain")
    func insertWithBufferedSuccessors() {
        var buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(0))
        // Buffer packets 1 and 2 first (ahead of expected 0)
        _ = buf.insert(makePacket(seq: 1))
        _ = buf.insert(makePacket(seq: 2))
        // Now insert the expected packet 0
        let result = buf.insert(makePacket(seq: 0))
        if case .deliverable(let packets) = result {
            #expect(packets.count == 3)
            #expect(packets[0].sequenceNumber == SequenceNumber(0))
            #expect(packets[1].sequenceNumber == SequenceNumber(1))
            #expect(packets[2].sequenceNumber == SequenceNumber(2))
        } else {
            #expect(Bool(false), "Expected deliverable chain")
        }
    }

    @Test("Multiple in-order inserts each returns deliverable")
    func multipleInOrder() {
        var buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(0))
        for i: UInt32 in 0..<5 {
            let result = buf.insert(makePacket(seq: i))
            if case .deliverable(let packets) = result {
                #expect(packets.count == 1)
            } else {
                #expect(Bool(false), "Expected deliverable for seq \(i)")
            }
        }
        #expect(buf.nextExpected == SequenceNumber(5))
    }

    // MARK: - Out-of-order

    @Test("Insert ahead of expected returns buffered")
    func insertAheadOfExpected() {
        var buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(0))
        let result = buf.insert(makePacket(seq: 5))
        #expect(result == .buffered)
        #expect(buf.bufferedCount == 1)
    }

    @Test("Insert fills gap triggers delivery chain")
    func insertFillsGap() {
        var buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(0))
        _ = buf.insert(makePacket(seq: 1))
        _ = buf.insert(makePacket(seq: 2))
        #expect(buf.bufferedCount == 2)
        let result = buf.insert(makePacket(seq: 0))
        if case .deliverable(let packets) = result {
            #expect(packets.count == 3)
        } else {
            #expect(Bool(false), "Expected deliverable")
        }
        #expect(buf.bufferedCount == 0)
    }

    @Test("Insert way ahead creates large gap")
    func insertWayAhead() {
        var buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(0))
        let result = buf.insert(makePacket(seq: 100))
        #expect(result == .buffered)
        #expect(buf.hasGaps)
    }

    // MARK: - Duplicates

    @Test("Insert same sequence twice returns duplicate")
    func duplicateInBuffer() {
        var buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(0))
        _ = buf.insert(makePacket(seq: 5))
        let result = buf.insert(makePacket(seq: 5))
        #expect(result == .duplicate)
    }

    @Test("Insert already-delivered sequence returns tooOld")
    func insertAlreadyDelivered() {
        var buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(0))
        _ = buf.insert(makePacket(seq: 0))
        _ = buf.insert(makePacket(seq: 1))
        // Sequence 0 already delivered, nextExpected is 2
        let result = buf.insert(makePacket(seq: 0))
        #expect(result == .tooOld)
    }

    // MARK: - Gap tracking

    @Test("hasGaps reflects missing packets")
    func hasGaps() {
        var buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(0))
        #expect(!buf.hasGaps)
        _ = buf.insert(makePacket(seq: 2))
        #expect(buf.hasGaps)
    }

    @Test("missingSequenceNumbers lists correct gaps")
    func missingSequenceNumbers() {
        var buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(0))
        _ = buf.insert(makePacket(seq: 3))
        let missing = buf.missingSequenceNumbers
        #expect(missing.count == 3)
        #expect(missing.contains(SequenceNumber(0)))
        #expect(missing.contains(SequenceNumber(1)))
        #expect(missing.contains(SequenceNumber(2)))
    }

    @Test("Gap filled reduces hasGaps")
    func gapFilled() {
        var buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(0))
        _ = buf.insert(makePacket(seq: 2))
        _ = buf.insert(makePacket(seq: 1))
        _ = buf.insert(makePacket(seq: 0))
        #expect(!buf.hasGaps)
    }

    @Test("Multiple gaps tracked simultaneously")
    func multipleGaps() {
        var buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(0))
        _ = buf.insert(makePacket(seq: 2))
        _ = buf.insert(makePacket(seq: 5))
        let missing = buf.missingSequenceNumbers
        // Missing: 0, 1, 3, 4
        #expect(missing.count == 4)
        #expect(missing.contains(SequenceNumber(0)))
        #expect(missing.contains(SequenceNumber(1)))
        #expect(missing.contains(SequenceNumber(3)))
        #expect(missing.contains(SequenceNumber(4)))
    }

    // MARK: - Properties

    @Test("nextExpected starts at initial value")
    func nextExpectedInitial() {
        let buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(42))
        #expect(buf.nextExpected == SequenceNumber(42))
    }

    @Test("lastAcknowledged equals nextExpected minus 1")
    func lastAcknowledged() {
        var buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(10))
        #expect(buf.lastAcknowledged == SequenceNumber(9))
        _ = buf.insert(makePacket(seq: 10))
        #expect(buf.lastAcknowledged == SequenceNumber(10))
    }

    @Test("bufferedCount reflects out-of-order packets only")
    func bufferedCount() {
        var buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(0))
        _ = buf.insert(makePacket(seq: 0))  // delivered
        _ = buf.insert(makePacket(seq: 5))  // buffered
        _ = buf.insert(makePacket(seq: 7))  // buffered
        #expect(buf.bufferedCount == 2)
    }

    @Test("deliverableCount counts consecutive buffered at head")
    func deliverableCount() {
        var buf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(0))
        // Buffer 0, 1, 2 but with a gap at 0 (nextExpected = 0)
        _ = buf.insert(makePacket(seq: 3))
        _ = buf.insert(makePacket(seq: 4))
        _ = buf.insert(makePacket(seq: 5))
        // deliverableCount looks from nextExpected (0), no buffered at 0
        #expect(buf.deliverableCount == 0)
    }
}
