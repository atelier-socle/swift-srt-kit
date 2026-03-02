// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SendBuffer Wrap-Around Tests")
struct SendBufferWrapAroundTests {
    private func makeEntry(
        seq: UInt32,
        payload: [UInt8] = [0xAB],
        timestamp: UInt64 = 1000
    ) -> SendBuffer.Entry {
        SendBuffer.Entry(
            sequenceNumber: SequenceNumber(seq),
            payload: payload,
            sentTimestamp: timestamp
        )
    }

    // MARK: - Wrap-around

    @Test("Insert across sequence wrap-around boundary")
    func insertAcrossWrap() {
        var buf = SendBuffer(capacity: 10)
        let nearMax = SequenceNumber.max - 2
        buf.insert(makeEntry(seq: nearMax))
        buf.insert(makeEntry(seq: nearMax + 1))
        buf.insert(makeEntry(seq: nearMax + 2))  // == SequenceNumber.max
        buf.insert(makeEntry(seq: 0))  // wraps to 0
        buf.insert(makeEntry(seq: 1))
        #expect(buf.count == 5)
    }

    @Test("Acknowledge across wrap-around boundary")
    func acknowledgeAcrossWrap() {
        var buf = SendBuffer(capacity: 10)
        let nearMax = SequenceNumber.max - 1
        buf.insert(makeEntry(seq: nearMax))
        buf.insert(makeEntry(seq: nearMax + 1))  // == SequenceNumber.max
        buf.insert(makeEntry(seq: 0))
        buf.insert(makeEntry(seq: 1))
        // Acknowledge up to 0 (wraps past max)
        let removed = buf.acknowledge(upTo: SequenceNumber(0))
        #expect(removed == 3)  // nearMax, max, 0
        #expect(buf.count == 1)  // only seq 1 remains
    }

    @Test("Retrieve across wrap-around boundary")
    func retrieveAcrossWrap() {
        var buf = SendBuffer(capacity: 10)
        buf.insert(makeEntry(seq: SequenceNumber.max, payload: [0xFF]))
        buf.insert(makeEntry(seq: 0, payload: [0x00]))
        let entryMax = buf.retrieve(sequenceNumber: SequenceNumber(SequenceNumber.max))
        let entryZero = buf.retrieve(sequenceNumber: SequenceNumber(0))
        #expect(entryMax?.payload == [0xFF])
        #expect(entryZero?.payload == [0x00])
    }

    // MARK: - Drop

    @Test("dropOlderThan removes old entries")
    func dropOlderThan() {
        var buf = SendBuffer(capacity: 10)
        buf.insert(makeEntry(seq: 0, timestamp: 100))
        buf.insert(makeEntry(seq: 1, timestamp: 200))
        buf.insert(makeEntry(seq: 2, timestamp: 300))
        let dropped = buf.dropOlderThan(timestamp: 250)
        #expect(dropped.count == 2)
        #expect(buf.count == 1)
    }

    @Test("dropOlderThan returns dropped sequence numbers")
    func dropOlderThanReturnsSequences() {
        var buf = SendBuffer(capacity: 10)
        buf.insert(makeEntry(seq: 10, timestamp: 100))
        buf.insert(makeEntry(seq: 11, timestamp: 200))
        let dropped = buf.dropOlderThan(timestamp: 150)
        #expect(dropped.count == 1)
        #expect(dropped.contains(SequenceNumber(10)))
    }

    @Test("dropOlderThan preserves recent entries")
    func dropOlderThanPreservesRecent() {
        var buf = SendBuffer(capacity: 10)
        buf.insert(makeEntry(seq: 0, timestamp: 500))
        buf.insert(makeEntry(seq: 1, timestamp: 600))
        let dropped = buf.dropOlderThan(timestamp: 100)
        #expect(dropped.isEmpty)
        #expect(buf.count == 2)
    }
}
