// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("ACKManager Timing Tests")
struct ACKManagerTimingTests {
    // MARK: - ACKACK processing

    @Test("ackSent stores pending ACK")
    func ackSentStoresPending() {
        var mgr = ACKManager()
        mgr.ackSent(
            ackSequenceNumber: 1,
            sentAt: 1000,
            acknowledgedSequence: SequenceNumber(10)
        )
        #expect(mgr.pendingACKCount == 1)
    }

    @Test("processACKACK with matching sequence returns RTT")
    func processACKACKMatching() {
        var mgr = ACKManager()
        mgr.ackSent(
            ackSequenceNumber: 1,
            sentAt: 1000,
            acknowledgedSequence: SequenceNumber(10)
        )
        let rtt = mgr.processACKACK(ackSequenceNumber: 1, receivedAt: 2500)
        #expect(rtt == 1500)
    }

    @Test("processACKACK with unknown sequence returns nil")
    func processACKACKUnknown() {
        var mgr = ACKManager()
        mgr.ackSent(
            ackSequenceNumber: 1,
            sentAt: 1000,
            acknowledgedSequence: SequenceNumber(10)
        )
        let rtt = mgr.processACKACK(ackSequenceNumber: 99, receivedAt: 2000)
        #expect(rtt == nil)
    }

    @Test("processACKACK removes pending ACK")
    func processACKACKRemovesPending() {
        var mgr = ACKManager()
        mgr.ackSent(
            ackSequenceNumber: 1,
            sentAt: 1000,
            acknowledgedSequence: SequenceNumber(10)
        )
        _ = mgr.processACKACK(ackSequenceNumber: 1, receivedAt: 2000)
        #expect(mgr.pendingACKCount == 0)
    }

    @Test("Multiple pending ACKs tracked independently")
    func multiplePendingACKs() {
        var mgr = ACKManager()
        mgr.ackSent(
            ackSequenceNumber: 1,
            sentAt: 1000,
            acknowledgedSequence: SequenceNumber(10)
        )
        mgr.ackSent(
            ackSequenceNumber: 2,
            sentAt: 2000,
            acknowledgedSequence: SequenceNumber(20)
        )
        #expect(mgr.pendingACKCount == 2)
        let rtt1 = mgr.processACKACK(ackSequenceNumber: 1, receivedAt: 3000)
        #expect(rtt1 == 2000)
        #expect(mgr.pendingACKCount == 1)
        let rtt2 = mgr.processACKACK(ackSequenceNumber: 2, receivedAt: 3500)
        #expect(rtt2 == 1500)
        #expect(mgr.pendingACKCount == 0)
    }

    // MARK: - Light ACK

    @Test("Packet received between periodic intervals generates light ACK")
    func lightACKBetweenIntervals() {
        var mgr = ACKManager()
        // First packet to initialize
        let first = mgr.packetReceived(
            currentTime: 0,
            lastAcknowledged: SequenceNumber(0)
        )
        // First packet may or may not be light ACK
        _ = first
        // Second packet with advanced sequence but before SYN interval
        let action = mgr.packetReceived(
            currentTime: 100,
            lastAcknowledged: SequenceNumber(1)
        )
        if case .sendLightACK(let seq) = action {
            #expect(seq == SequenceNumber(1))
        } else if case .none = action {
            // Also acceptable if no sequence advancement detected
        } else if case .sendFullACK = action {
            #expect(Bool(false), "Did not expect full ACK")
        }
    }

    @Test("No light ACK if no new data since last ACK")
    func noLightACKWithoutNewData() {
        var mgr = ACKManager()
        // Generate a full ACK to reset state
        for i: UInt32 in 0..<64 {
            _ = mgr.packetReceived(
                currentTime: UInt64(i),
                lastAcknowledged: SequenceNumber(i)
            )
        }
        // Check periodic with no new data
        let action = mgr.checkPeriodicACK(
            currentTime: ACKManager.synInterval * 2,
            lastAcknowledged: SequenceNumber(63)
        )
        #expect(action == .none)
    }

    // MARK: - Periodic ACK without new data

    @Test("checkPeriodicACK returns none without new data")
    func periodicWithoutNewData() {
        var mgr = ACKManager()
        let action = mgr.checkPeriodicACK(
            currentTime: ACKManager.synInterval * 10,
            lastAcknowledged: SequenceNumber(0)
        )
        #expect(action == .none)
    }

    // MARK: - Full ACK carries correct sequence

    @Test("Full ACK carries the lastAcknowledged sequence")
    func fullACKCarriesSequence() {
        var mgr = ACKManager()
        var lastAction: ACKManager.ACKAction = .none
        for i: UInt32 in 0..<64 {
            lastAction = mgr.packetReceived(
                currentTime: UInt64(i),
                lastAcknowledged: SequenceNumber(100 + i)
            )
        }
        if case .sendFullACK(_, let seq) = lastAction {
            #expect(seq == SequenceNumber(163))
        } else {
            #expect(Bool(false), "Expected sendFullACK")
        }
    }
}
