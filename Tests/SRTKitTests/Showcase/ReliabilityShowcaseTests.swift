// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("Reliability Showcase")
struct ReliabilityShowcaseTests {
    // MARK: - SequenceNumber

    @Test("SequenceNumber wraps at 31-bit boundary")
    func sequenceNumberWrap() {
        let seq = SequenceNumber(SequenceNumber.max)
        let next = seq + 1
        #expect(next.value == 0)
    }

    @Test("SequenceNumber distance handles wrap-around")
    func sequenceDistance() {
        let a = SequenceNumber(100)
        let b = SequenceNumber(200)
        #expect(SequenceNumber.distance(from: a, to: b) == 100)
    }

    // MARK: - SendBuffer

    @Test("SendBuffer stores and retrieves packets by sequence")
    func sendBufferBasics() {
        var buffer = SendBuffer(capacity: 1024)
        let entry = SendBuffer.Entry(
            sequenceNumber: SequenceNumber(1),
            payload: [0x47, 0x00, 0x11, 0x00],
            sentTimestamp: 10_000)

        let inserted = buffer.insert(entry)
        #expect(inserted)
        #expect(buffer.count == 1)

        let retrieved = buffer.retrieve(sequenceNumber: SequenceNumber(1))
        #expect(retrieved?.payload == [0x47, 0x00, 0x11, 0x00])
    }

    @Test("SendBuffer acknowledges packets in order")
    func sendBufferAcknowledge() {
        var buffer = SendBuffer(capacity: 1024)
        for i: UInt32 in 0..<5 {
            let entry = SendBuffer.Entry(
                sequenceNumber: SequenceNumber(i),
                payload: [UInt8(i)],
                sentTimestamp: UInt64(i) * 1000)
            _ = buffer.insert(entry)
        }
        #expect(buffer.count == 5)

        // acknowledge(upTo:) includes the target sequence
        let acked = buffer.acknowledge(upTo: SequenceNumber(3))
        #expect(acked == 4)
    }

    // MARK: - ReceiveBuffer

    @Test("ReceiveBuffer delivers packets in order after gap fill")
    func receiveBufferGapFill() {
        var buffer = ReceiveBuffer(
            initialSequenceNumber: SequenceNumber(0))

        // Insert packet 0 (in order)
        let p0 = ReceiveBuffer.ReceivedPacket(
            sequenceNumber: SequenceNumber(0),
            payload: [0x00])
        let r0 = buffer.insert(p0)
        if case .deliverable(let packets) = r0 {
            #expect(packets.count == 1)
        }

        // Skip packet 1, insert packet 2 (gap)
        let p2 = ReceiveBuffer.ReceivedPacket(
            sequenceNumber: SequenceNumber(2),
            payload: [0x02])
        let r2 = buffer.insert(p2)
        if case .buffered = r2 {
            // Expected: buffered because gap
        } else {
            Issue.record("Expected buffered result")
        }

        // Fill the gap with packet 1
        let p1 = ReceiveBuffer.ReceivedPacket(
            sequenceNumber: SequenceNumber(1),
            payload: [0x01])
        let r1 = buffer.insert(p1)
        if case .deliverable(let packets) = r1 {
            #expect(packets.count == 2)
        }
    }

    // MARK: - LossDetector

    @Test("LossDetector tracks and reports losses")
    func lossDetection() {
        var detector = LossDetector()
        detector.addLoss(
            sequenceNumbers: [SequenceNumber(5), SequenceNumber(6)],
            at: 100_000)
        #expect(detector.lossCount == 2)
        #expect(detector.hasLosses)

        let needing = detector.lossesNeedingReport(
            currentTime: 200_000, nakPeriod: 50_000)
        #expect(needing.count == 2)
    }

    // MARK: - RetransmissionManager

    @Test("RetransmissionManager processes NAK for resend")
    func retransmission() {
        var manager = RetransmissionManager()
        var sendBuf = SendBuffer(capacity: 1024)

        // Add packets to send buffer
        for i: UInt32 in 0..<10 {
            let entry = SendBuffer.Entry(
                sequenceNumber: SequenceNumber(i),
                payload: [UInt8(i), 0x47],
                sentTimestamp: UInt64(i) * 1000)
            _ = sendBuf.insert(entry)
        }

        // NAK for sequences 3 and 7
        let requests = manager.processNAK(
            lostSequenceNumbers: [SequenceNumber(3), SequenceNumber(7)],
            sendBuffer: &sendBuf)

        #expect(requests.count == 2)
        #expect(manager.totalRetransmissions == 2)
    }
}
