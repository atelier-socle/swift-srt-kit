// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("ACKManager Tests")
struct ACKManagerTests {
    // MARK: - Packet counting

    @Test("First 63 packets return no full ACK")
    func first63NoFullACK() {
        var mgr = ACKManager()
        for i in 0..<63 {
            let action = mgr.packetReceived(
                currentTime: UInt64(i),
                lastAcknowledged: SequenceNumber(UInt32(i))
            )
            if case .sendFullACK = action {
                #expect(Bool(false), "Did not expect full ACK at packet \(i)")
            }
        }
    }

    @Test("64th packet triggers sendFullACK")
    func packet64TriggersFullACK() {
        var mgr = ACKManager()
        var action: ACKManager.ACKAction = .none
        for i: UInt32 in 0..<64 {
            action = mgr.packetReceived(
                currentTime: UInt64(i),
                lastAcknowledged: SequenceNumber(i)
            )
        }
        if case .sendFullACK = action {
            // Expected
        } else {
            #expect(Bool(false), "Expected sendFullACK at packet 64")
        }
    }

    @Test("Counter resets after full ACK, next 64 triggers another")
    func counterResetsAfterFullACK() {
        var mgr = ACKManager()
        // First 64
        for i: UInt32 in 0..<64 {
            _ = mgr.packetReceived(
                currentTime: UInt64(i),
                lastAcknowledged: SequenceNumber(i)
            )
        }
        // Next 63 should not trigger
        for i: UInt32 in 64..<127 {
            let action = mgr.packetReceived(
                currentTime: UInt64(i),
                lastAcknowledged: SequenceNumber(i)
            )
            if case .sendFullACK = action {
                #expect(Bool(false), "Did not expect full ACK at packet \(i)")
            }
        }
        // 128th (64th since last full ACK) should trigger
        let action = mgr.packetReceived(
            currentTime: 127,
            lastAcknowledged: SequenceNumber(127)
        )
        if case .sendFullACK = action {
            // Expected
        } else {
            #expect(Bool(false), "Expected sendFullACK at 128th packet")
        }
    }

    // MARK: - Periodic timing

    @Test("Before SYN interval no full ACK from timer")
    func beforeSynInterval() {
        var mgr = ACKManager()
        let action = mgr.checkPeriodicACK(
            currentTime: ACKManager.synInterval - 1,
            lastAcknowledged: SequenceNumber(0)
        )
        #expect(action == .none)
    }

    @Test("At SYN interval triggers full ACK")
    func atSynInterval() {
        var mgr = ACKManager()
        // Need to mark that new data arrived
        _ = mgr.packetReceived(currentTime: 0, lastAcknowledged: SequenceNumber(0))
        let action = mgr.checkPeriodicACK(
            currentTime: ACKManager.synInterval,
            lastAcknowledged: SequenceNumber(1)
        )
        if case .sendFullACK = action {
            // Expected
        } else {
            #expect(Bool(false), "Expected sendFullACK at SYN interval")
        }
    }

    @Test("Timer resets after full ACK")
    func timerResetsAfterFullACK() {
        var mgr = ACKManager()
        _ = mgr.packetReceived(currentTime: 0, lastAcknowledged: SequenceNumber(0))
        _ = mgr.checkPeriodicACK(
            currentTime: ACKManager.synInterval,
            lastAcknowledged: SequenceNumber(1)
        )
        // Immediately after, no new data → should not trigger
        let action = mgr.checkPeriodicACK(
            currentTime: ACKManager.synInterval + 1,
            lastAcknowledged: SequenceNumber(1)
        )
        #expect(action == .none)
    }

    // MARK: - ACK sequence numbering

    @Test("ACK sequence number starts at 1")
    func ackSequenceStartsAt1() {
        let mgr = ACKManager()
        #expect(mgr.currentACKSequenceNumber == 1)
    }

    @Test("ACK sequence increments on each full ACK")
    func ackSequenceIncrements() {
        var mgr = ACKManager()
        for i: UInt32 in 0..<64 {
            _ = mgr.packetReceived(
                currentTime: UInt64(i),
                lastAcknowledged: SequenceNumber(i)
            )
        }
        #expect(mgr.currentACKSequenceNumber == 2)
        for i: UInt32 in 64..<128 {
            _ = mgr.packetReceived(
                currentTime: UInt64(i),
                lastAcknowledged: SequenceNumber(i)
            )
        }
        #expect(mgr.currentACKSequenceNumber == 3)
    }
}
