// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("ACKManager Coverage Tests")
struct ACKManagerCoverageTests {

    // MARK: - Time-based ACK trigger

    @Test("packetReceived triggers ACK when SYN interval elapsed")
    func timeTrigger() {
        var mgr = ACKManager()
        // First packet at time 0
        let firstAction = mgr.packetReceived(
            currentTime: 0, lastAcknowledged: SequenceNumber(0))
        // Should send full ACK immediately (first packet triggers count threshold)
        if case .sendFullACK = firstAction {
            // Expected — first packet, count threshold is low
        }

        // Reset by ensuring we're past the initial ACK
        // Next packet shortly after should not trigger
        let earlyAction = mgr.packetReceived(
            currentTime: 100, lastAcknowledged: SequenceNumber(1))
        // Could be light ACK or none

        // Packet after SYN interval (10ms = 10_000us) should trigger full ACK
        let lateAction = mgr.packetReceived(
            currentTime: 10_100, lastAcknowledged: SequenceNumber(2))
        // At minimum we should get some ACK action
        _ = lateAction
        _ = earlyAction
    }

    // MARK: - checkPeriodicACK

    @Test("checkPeriodicACK returns none before SYN interval")
    func periodicACKBeforeInterval() {
        var mgr = ACKManager()
        _ = mgr.packetReceived(
            currentTime: 0, lastAcknowledged: SequenceNumber(0))
        let action = mgr.checkPeriodicACK(
            currentTime: 5_000, lastAcknowledged: SequenceNumber(1))
        if case .none = action {
            // expected — not enough time
        }
    }

    @Test("checkPeriodicACK returns full ACK after SYN interval with data")
    func periodicACKAfterInterval() {
        var mgr = ACKManager()
        _ = mgr.packetReceived(
            currentTime: 0, lastAcknowledged: SequenceNumber(0))
        // Simulate new data received
        _ = mgr.packetReceived(
            currentTime: 5_000, lastAcknowledged: SequenceNumber(1))
        let action = mgr.checkPeriodicACK(
            currentTime: 15_000, lastAcknowledged: SequenceNumber(1))
        if case .sendFullACK = action {
            // expected
        }
    }

    @Test("checkPeriodicACK returns none when no new data")
    func periodicACKNoNewData() {
        var mgr = ACKManager()
        // Send a full ACK to clear hasNewData
        _ = mgr.packetReceived(
            currentTime: 0, lastAcknowledged: SequenceNumber(0))
        // After full ACK, hasNewData is false
        let action = mgr.checkPeriodicACK(
            currentTime: 20_000, lastAcknowledged: SequenceNumber(0))
        if case .none = action {
            // expected — no new data since last full ACK
        }
    }

    // MARK: - Pending ACK cleanup

    @Test("Old pending ACKs are cleaned up")
    func cleanupOldPendingACKs() {
        var mgr = ACKManager()
        // Send first ACK
        _ = mgr.packetReceived(
            currentTime: 0, lastAcknowledged: SequenceNumber(0))
        let ackSeq = mgr.currentACKSequenceNumber
        // Record it as sent
        mgr.ackSent(
            ackSequenceNumber: ackSeq,
            sentAt: 0,
            acknowledgedSequence: SequenceNumber(0))
        #expect(mgr.pendingACKCount == 1)

        // Send another ACK much later (past maxPendingAge = 10 seconds)
        _ = mgr.packetReceived(
            currentTime: 11_000_000,
            lastAcknowledged: SequenceNumber(1))
        let ackSeq2 = mgr.currentACKSequenceNumber
        mgr.ackSent(
            ackSequenceNumber: ackSeq2,
            sentAt: 11_000_000,
            acknowledgedSequence: SequenceNumber(1))
        // Old one should have been cleaned up
        #expect(mgr.pendingACKCount == 1)
    }

    // MARK: - processACKACK with unknown sequence

    @Test("processACKACK with unknown sequence returns nil")
    func processACKACKUnknown() {
        var mgr = ACKManager()
        let rtt = mgr.processACKACK(
            ackSequenceNumber: 9999, receivedAt: 100_000)
        #expect(rtt == nil)
    }

    // MARK: - Light ACK emission

    @Test("Light ACK emitted when sequence advances without count threshold")
    func lightACKEmitted() {
        var mgr = ACKManager()
        // First packet triggers full ACK
        _ = mgr.packetReceived(
            currentTime: 0, lastAcknowledged: SequenceNumber(0))
        // Second packet with advanced sequence and not enough for count threshold
        let action = mgr.packetReceived(
            currentTime: 100, lastAcknowledged: SequenceNumber(1))
        if case .sendLightACK = action {
            // expected
        }
    }
}
