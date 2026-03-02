// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("Reliability Integration Tests")
struct ReliabilityIntegrationTests {
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

    private func makePacket(
        seq: UInt32,
        payload: [UInt8] = [0xCD]
    ) -> ReceiveBuffer.ReceivedPacket {
        ReceiveBuffer.ReceivedPacket(
            sequenceNumber: SequenceNumber(seq),
            payload: payload
        )
    }

    // MARK: - Full flow

    @Test("Send 10 packets, receive all in order, all delivered")
    func sendReceiveInOrder() {
        var recvBuf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(0))
        var deliveredCount = 0

        for i: UInt32 in 0..<10 {
            let result = recvBuf.insert(makePacket(seq: i))
            if case .deliverable(let packets) = result {
                deliveredCount += packets.count
            }
        }

        #expect(deliveredCount == 10)
        #expect(recvBuf.nextExpected == SequenceNumber(10))
        #expect(!recvBuf.hasGaps)
    }

    @Test("Receive with gap detects loss and generates NAK list")
    func receiveWithGapDetectsLoss() {
        var recvBuf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(0))
        var detector = LossDetector()
        var deliveredCount = 0

        // Receive 0-3
        for i: UInt32 in 0..<4 {
            let result = recvBuf.insert(makePacket(seq: i))
            if case .deliverable(let packets) = result {
                deliveredCount += packets.count
            }
        }
        #expect(deliveredCount == 4)

        // Skip 4, receive 5-9
        for i: UInt32 in 5..<10 {
            let result = recvBuf.insert(makePacket(seq: i))
            if case .buffered = result {
                // Expected for out-of-order
            }
        }

        // Detect loss
        let missing = recvBuf.missingSequenceNumbers
        #expect(missing == [SequenceNumber(4)])
        detector.addLoss(sequenceNumbers: missing, at: 1000)
        #expect(detector.lossCount == 1)
    }

    @Test("NAK triggers retransmission from send buffer")
    func nakTriggersRetransmission() {
        var sendBuf = SendBuffer(capacity: 20)
        var retransMgr = RetransmissionManager()

        // Sender has packets 0-9 in buffer
        for i: UInt32 in 0..<10 {
            sendBuf.insert(makeEntry(seq: i, payload: [UInt8(i)]))
        }

        // NAK reports packet 4 as lost
        let requests = retransMgr.processNAK(
            lostSequenceNumbers: [SequenceNumber(4)],
            sendBuffer: &sendBuf
        )

        #expect(requests.count == 1)
        #expect(requests[0].sequenceNumber == SequenceNumber(4))
        #expect(requests[0].payload == [4])
        #expect(requests[0].sendCount == 2)
        #expect(retransMgr.totalRetransmissions == 1)
    }

    @Test("Gap filled delivers remaining packets")
    func gapFilledDeliversRemaining() {
        var recvBuf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(0))

        // Receive 0-3
        for i: UInt32 in 0..<4 {
            _ = recvBuf.insert(makePacket(seq: i))
        }
        // Skip 4, receive 5-7
        for i: UInt32 in 5..<8 {
            _ = recvBuf.insert(makePacket(seq: i))
        }
        #expect(recvBuf.bufferedCount == 3)

        // Retransmitted packet 4 arrives
        let result = recvBuf.insert(makePacket(seq: 4))
        if case .deliverable(let packets) = result {
            #expect(packets.count == 4)  // 4, 5, 6, 7
            #expect(packets[0].sequenceNumber == SequenceNumber(4))
            #expect(packets[3].sequenceNumber == SequenceNumber(7))
        } else {
            #expect(Bool(false), "Expected deliverable chain")
        }
    }

    @Test("Full ACK + ACKACK measures RTT")
    func fullACKAndACKACKMeasuresRTT() {
        var ackMgr = ACKManager()
        var rttEstimator = RTTEstimator()

        // Simulate 64 packets to trigger full ACK
        var action: ACKManager.ACKAction = .none
        for i: UInt32 in 0..<64 {
            action = ackMgr.packetReceived(
                currentTime: UInt64(i * 100),
                lastAcknowledged: SequenceNumber(i)
            )
        }

        if case .sendFullACK(let ackSeq, _) = action {
            // Record the ACK as sent
            let sentTime: UInt64 = 6400
            ackMgr.ackSent(
                ackSequenceNumber: ackSeq,
                sentAt: sentTime,
                acknowledgedSequence: SequenceNumber(63)
            )

            // ACKACK arrives 50ms later
            let rtt = ackMgr.processACKACK(
                ackSequenceNumber: ackSeq,
                receivedAt: sentTime + 50_000
            )
            #expect(rtt == 50_000)

            // Update RTT estimator
            if let measuredRTT = rtt {
                rttEstimator.update(rtt: measuredRTT)
                #expect(rttEstimator.smoothedRTT == 50_000)
                #expect(rttEstimator.sampleCount == 1)
            }
        } else {
            #expect(Bool(false), "Expected sendFullACK")
        }
    }

    @Test("ACK frees send buffer space")
    func ackFreesSendBufferSpace() {
        var sendBuf = SendBuffer(capacity: 10)

        // Fill buffer
        for i: UInt32 in 0..<10 {
            sendBuf.insert(makeEntry(seq: i))
        }
        #expect(sendBuf.isFull)
        let blocked = sendBuf.insert(makeEntry(seq: 10))
        #expect(!blocked)

        // ACK up to 4
        sendBuf.acknowledge(upTo: SequenceNumber(4))
        #expect(!sendBuf.isFull)
        #expect(sendBuf.availableSpace == 5)

        // Now can insert more
        let ok = sendBuf.insert(makeEntry(seq: 10))
        #expect(ok)
    }

    @Test("Send buffer full blocks insertion until ACK")
    func sendBufferFullBlocksInsertion() {
        var sendBuf = SendBuffer(capacity: 5)
        for i: UInt32 in 0..<5 {
            let ok = sendBuf.insert(makeEntry(seq: i))
            #expect(ok)
        }
        let blocked = sendBuf.insert(makeEntry(seq: 5))
        #expect(!blocked)

        // ACK frees space
        sendBuf.acknowledge(upTo: SequenceNumber(0))
        let ok = sendBuf.insert(makeEntry(seq: 5))
        #expect(ok)
    }

    @Test("Sequence wrap-around across all components")
    func wrapAroundAcrossComponents() {
        let nearMax = SequenceNumber.max - 4
        var sendBuf = SendBuffer(capacity: 20)
        var recvBuf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(nearMax))

        // Insert 10 packets crossing the wrap-around boundary
        for i: Int32 in 0..<10 {
            let seq = SequenceNumber(nearMax) + i
            sendBuf.insert(makeEntry(seq: seq.value))
            let result = recvBuf.insert(makePacket(seq: seq.value))
            if case .deliverable = result {
                // Good
            } else {
                #expect(Bool(false), "Expected deliverable for offset \(i)")
            }
        }

        #expect(sendBuf.count == 10)
        // ACK across wrap
        sendBuf.acknowledge(upTo: SequenceNumber(2))
        // Should have removed packets nearMax through 2 (8 packets)
        #expect(sendBuf.count == 2)
    }

    @Test("Multiple losses and recoveries in sequence")
    func multipleLossesAndRecoveries() {
        var recvBuf = ReceiveBuffer(initialSequenceNumber: SequenceNumber(0))
        var detector = LossDetector()
        var totalDelivered = 0

        // Receive 0, skip 1, receive 2, skip 3, receive 4-5
        _ = recvBuf.insert(makePacket(seq: 0))
        totalDelivered += 1
        _ = recvBuf.insert(makePacket(seq: 2))
        _ = recvBuf.insert(makePacket(seq: 4))
        _ = recvBuf.insert(makePacket(seq: 5))

        let missing = recvBuf.missingSequenceNumbers
        // Missing: 1, 3
        #expect(missing.count == 2)
        detector.addLoss(sequenceNumbers: missing, at: 1000)

        // Recover packet 1
        let r1 = recvBuf.insert(makePacket(seq: 1))
        if case .deliverable(let packets) = r1 {
            totalDelivered += packets.count  // delivers 1, 2
        }
        detector.removeLoss(sequenceNumbers: [SequenceNumber(1)])

        // Recover packet 3
        let r3 = recvBuf.insert(makePacket(seq: 3))
        if case .deliverable(let packets) = r3 {
            totalDelivered += packets.count  // delivers 3, 4, 5
        }
        detector.removeLoss(sequenceNumbers: [SequenceNumber(3)])

        #expect(totalDelivered == 6)
        #expect(!detector.hasLosses)
        #expect(recvBuf.nextExpected == SequenceNumber(6))
    }

    @Test("Periodic NAK re-report for unrecovered loss")
    func periodicNAKReReport() {
        var detector = LossDetector()
        detector.addLoss(sequenceNumbers: [SequenceNumber(5)], at: 1000)

        // First report
        let first = detector.lossesNeedingReport(currentTime: 1000, nakPeriod: 50_000)
        #expect(first.count == 1)
        detector.markReported(sequenceNumbers: first, at: 1000)

        // Within NAK period — no re-report
        let within = detector.lossesNeedingReport(currentTime: 30_000, nakPeriod: 50_000)
        #expect(within.isEmpty)

        // Past NAK period — re-report
        let past = detector.lossesNeedingReport(currentTime: 51_001, nakPeriod: 50_000)
        #expect(past.count == 1)
    }
}
