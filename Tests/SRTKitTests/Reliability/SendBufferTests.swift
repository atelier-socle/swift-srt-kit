// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SendBuffer Tests")
struct SendBufferTests {
    private func makeEntry(
        seq: UInt32,
        payload: [UInt8] = [0xAB],
        timestamp: UInt64 = 1000,
        messageNumber: UInt32 = 0
    ) -> SendBuffer.Entry {
        SendBuffer.Entry(
            sequenceNumber: SequenceNumber(seq),
            payload: payload,
            sentTimestamp: timestamp,
            messageNumber: messageNumber
        )
    }

    // MARK: - Insert/Retrieve

    @Test("Insert single packet increases count")
    func insertSingle() {
        var buf = SendBuffer(capacity: 10)
        let ok = buf.insert(makeEntry(seq: 0))
        #expect(ok)
        #expect(buf.count == 1)
    }

    @Test("Insert up to capacity fills buffer")
    func insertToCapacity() {
        var buf = SendBuffer(capacity: 5)
        for i: UInt32 in 0..<5 {
            let ok = buf.insert(makeEntry(seq: i))
            #expect(ok)
        }
        #expect(buf.isFull)
        #expect(buf.count == 5)
    }

    @Test("Insert beyond capacity returns false")
    func insertBeyondCapacity() {
        var buf = SendBuffer(capacity: 2)
        let ok1 = buf.insert(makeEntry(seq: 0))
        #expect(ok1)
        let ok2 = buf.insert(makeEntry(seq: 1))
        #expect(ok2)
        let ok3 = buf.insert(makeEntry(seq: 2))
        #expect(!ok3)
        #expect(buf.count == 2)
    }

    @Test("Retrieve by sequence number returns correct payload")
    func retrieveBySequence() {
        var buf = SendBuffer(capacity: 10)
        buf.insert(makeEntry(seq: 42, payload: [1, 2, 3]))
        let entry = buf.retrieve(sequenceNumber: SequenceNumber(42))
        #expect(entry != nil)
        #expect(entry?.payload == [1, 2, 3])
    }

    @Test("Retrieve increments sendCount")
    func retrieveIncrementsCount() {
        var buf = SendBuffer(capacity: 10)
        buf.insert(makeEntry(seq: 10))
        let first = buf.retrieve(sequenceNumber: SequenceNumber(10))
        #expect(first?.sendCount == 2)
        let second = buf.retrieve(sequenceNumber: SequenceNumber(10))
        #expect(second?.sendCount == 3)
    }

    @Test("Retrieve non-existent returns nil")
    func retrieveNonExistent() {
        var buf = SendBuffer(capacity: 10)
        buf.insert(makeEntry(seq: 0))
        let entry = buf.retrieve(sequenceNumber: SequenceNumber(99))
        #expect(entry == nil)
    }

    @Test("Retrieve batch returns only found entries")
    func retrieveBatch() {
        var buf = SendBuffer(capacity: 10)
        buf.insert(makeEntry(seq: 1))
        buf.insert(makeEntry(seq: 3))
        let results = buf.retrieve(sequenceNumbers: [
            SequenceNumber(1), SequenceNumber(2), SequenceNumber(3)
        ])
        #expect(results.count == 2)
        #expect(results[0].sequenceNumber == SequenceNumber(1))
        #expect(results[1].sequenceNumber == SequenceNumber(3))
    }

    // MARK: - Acknowledge

    @Test("Acknowledge single removes it")
    func acknowledgeSingle() {
        var buf = SendBuffer(capacity: 10)
        buf.insert(makeEntry(seq: 5))
        let removed = buf.acknowledge(upTo: SequenceNumber(5))
        #expect(removed == 1)
        #expect(buf.count == 0)
    }

    @Test("Acknowledge range removes all packets up to N")
    func acknowledgeRange() {
        var buf = SendBuffer(capacity: 10)
        for i: UInt32 in 0..<5 {
            buf.insert(makeEntry(seq: i))
        }
        let removed = buf.acknowledge(upTo: SequenceNumber(2))
        #expect(removed == 3)
        #expect(buf.count == 2)
    }

    @Test("Acknowledge frees space")
    func acknowledgeFreesSpace() {
        var buf = SendBuffer(capacity: 3)
        for i: UInt32 in 0..<3 {
            buf.insert(makeEntry(seq: i))
        }
        #expect(buf.isFull)
        buf.acknowledge(upTo: SequenceNumber(0))
        #expect(!buf.isFull)
        #expect(buf.availableSpace == 1)
    }

    @Test("Acknowledge non-existent is idempotent")
    func acknowledgeNonExistent() {
        var buf = SendBuffer(capacity: 10)
        buf.insert(makeEntry(seq: 5))
        let removed = buf.acknowledge(upTo: SequenceNumber(3))
        #expect(removed == 0)
        #expect(buf.count == 1)
    }

    @Test("Acknowledge all makes buffer empty")
    func acknowledgeAll() {
        var buf = SendBuffer(capacity: 10)
        for i: UInt32 in 0..<5 {
            buf.insert(makeEntry(seq: i))
        }
        buf.acknowledge(upTo: SequenceNumber(4))
        #expect(buf.isEmpty)
    }

    @Test("Acknowledge returns correct removed count")
    func acknowledgeReturnCount() {
        var buf = SendBuffer(capacity: 10)
        for i: UInt32 in 10..<15 {
            buf.insert(makeEntry(seq: i))
        }
        let removed = buf.acknowledge(upTo: SequenceNumber(12))
        #expect(removed == 3)
    }

    // MARK: - Properties

    @Test("oldestSequenceNumber tracks correctly")
    func oldestSequenceNumber() {
        var buf = SendBuffer(capacity: 10)
        #expect(buf.oldestSequenceNumber == nil)
        buf.insert(makeEntry(seq: 3))
        buf.insert(makeEntry(seq: 5))
        #expect(buf.oldestSequenceNumber == SequenceNumber(3))
        buf.acknowledge(upTo: SequenceNumber(3))
        #expect(buf.oldestSequenceNumber == SequenceNumber(5))
    }

    @Test("newestSequenceNumber tracks correctly")
    func newestSequenceNumber() {
        var buf = SendBuffer(capacity: 10)
        #expect(buf.newestSequenceNumber == nil)
        buf.insert(makeEntry(seq: 3))
        #expect(buf.newestSequenceNumber == SequenceNumber(3))
        buf.insert(makeEntry(seq: 7))
        #expect(buf.newestSequenceNumber == SequenceNumber(7))
    }

    @Test("availableSpace equals capacity minus count")
    func availableSpace() {
        var buf = SendBuffer(capacity: 10)
        #expect(buf.availableSpace == 10)
        buf.insert(makeEntry(seq: 0))
        buf.insert(makeEntry(seq: 1))
        #expect(buf.availableSpace == 8)
    }

    @Test("removeAll clears buffer completely")
    func removeAll() {
        var buf = SendBuffer(capacity: 10)
        for i: UInt32 in 0..<5 {
            buf.insert(makeEntry(seq: i))
        }
        buf.removeAll()
        #expect(buf.isEmpty)
        #expect(buf.oldestSequenceNumber == nil)
        #expect(buf.newestSequenceNumber == nil)
    }
}
