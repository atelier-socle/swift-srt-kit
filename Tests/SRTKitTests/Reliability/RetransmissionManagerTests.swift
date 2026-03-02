// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("RetransmissionManager Tests")
struct RetransmissionManagerTests {
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

    @Test("processNAK with single loss returns 1 request")
    func processNAKSingleLoss() {
        var mgr = RetransmissionManager()
        var buf = SendBuffer(capacity: 10)
        buf.insert(makeEntry(seq: 5, payload: [1, 2, 3]))
        let requests = mgr.processNAK(
            lostSequenceNumbers: [SequenceNumber(5)],
            sendBuffer: &buf
        )
        #expect(requests.count == 1)
        #expect(requests[0].sequenceNumber == SequenceNumber(5))
        #expect(requests[0].payload == [1, 2, 3])
    }

    @Test("processNAK with range returns multiple requests")
    func processNAKRange() {
        var mgr = RetransmissionManager()
        var buf = SendBuffer(capacity: 10)
        for i: UInt32 in 5..<8 {
            buf.insert(makeEntry(seq: i))
        }
        let requests = mgr.processNAK(
            lostSequenceNumbers: [SequenceNumber(5), SequenceNumber(6), SequenceNumber(7)],
            sendBuffer: &buf
        )
        #expect(requests.count == 3)
    }

    @Test("processNAK for packet not in buffer increments missingFromBuffer")
    func processNAKMissing() {
        var mgr = RetransmissionManager()
        var buf = SendBuffer(capacity: 10)
        let requests = mgr.processNAK(
            lostSequenceNumbers: [SequenceNumber(99)],
            sendBuffer: &buf
        )
        #expect(requests.isEmpty)
        #expect(mgr.missingFromBuffer == 1)
    }

    @Test("RetransmitRequest has correct sendCount")
    func retransmitRequestSendCount() {
        var mgr = RetransmissionManager()
        var buf = SendBuffer(capacity: 10)
        buf.insert(makeEntry(seq: 5))
        let requests = mgr.processNAK(
            lostSequenceNumbers: [SequenceNumber(5)],
            sendBuffer: &buf
        )
        // retrieve increments sendCount from 1 to 2
        #expect(requests[0].sendCount == 2)
    }

    @Test("totalRetransmissions increments for each successful retrieval")
    func totalRetransmissions() {
        var mgr = RetransmissionManager()
        var buf = SendBuffer(capacity: 10)
        buf.insert(makeEntry(seq: 5))
        buf.insert(makeEntry(seq: 6))
        _ = mgr.processNAK(
            lostSequenceNumbers: [SequenceNumber(5), SequenceNumber(6)],
            sendBuffer: &buf
        )
        #expect(mgr.totalRetransmissions == 2)
    }

    @Test("processNAK with empty loss list returns no requests")
    func processNAKEmpty() {
        var mgr = RetransmissionManager()
        var buf = SendBuffer(capacity: 10)
        let requests = mgr.processNAK(
            lostSequenceNumbers: [],
            sendBuffer: &buf
        )
        #expect(requests.isEmpty)
        #expect(mgr.totalRetransmissions == 0)
    }

    @Test("processNAK with mix of found and missing")
    func processNAKMixed() {
        var mgr = RetransmissionManager()
        var buf = SendBuffer(capacity: 10)
        buf.insert(makeEntry(seq: 5))
        buf.insert(makeEntry(seq: 7))
        let requests = mgr.processNAK(
            lostSequenceNumbers: [SequenceNumber(5), SequenceNumber(6), SequenceNumber(7)],
            sendBuffer: &buf
        )
        #expect(requests.count == 2)
        #expect(mgr.totalRetransmissions == 2)
        #expect(mgr.missingFromBuffer == 1)
    }

    @Test("resetStatistics clears counters")
    func resetStatistics() {
        var mgr = RetransmissionManager()
        var buf = SendBuffer(capacity: 10)
        buf.insert(makeEntry(seq: 5))
        _ = mgr.processNAK(
            lostSequenceNumbers: [SequenceNumber(5), SequenceNumber(99)],
            sendBuffer: &buf
        )
        #expect(mgr.totalRetransmissions == 1)
        #expect(mgr.missingFromBuffer == 1)
        mgr.resetStatistics()
        #expect(mgr.totalRetransmissions == 0)
        #expect(mgr.missingFromBuffer == 0)
    }

    @Test("Retransmit request preserves original timestamp and payload")
    func retransmitRequestPreservesData() {
        var mgr = RetransmissionManager()
        var buf = SendBuffer(capacity: 10)
        buf.insert(makeEntry(seq: 42, payload: [0xDE, 0xAD], timestamp: 9999))
        let requests = mgr.processNAK(
            lostSequenceNumbers: [SequenceNumber(42)],
            sendBuffer: &buf
        )
        #expect(requests[0].payload == [0xDE, 0xAD])
        #expect(requests[0].originalTimestamp == 9999)
    }
}
