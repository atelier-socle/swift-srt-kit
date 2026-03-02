// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("BroadcastStrategy Tests")
struct BroadcastStrategyTests {
    // MARK: - Send

    @Test("prepareSend with 3 active members returns 3 target IDs")
    func sendToThreeMembers() {
        var strategy = BroadcastStrategy()
        let result = strategy.prepareSend(activeMembers: [1, 2, 3])
        #expect(result.targets.count == 3)
        #expect(result.targets.contains(1))
        #expect(result.targets.contains(2))
        #expect(result.targets.contains(3))
    }

    @Test("prepareSend increments group sequence")
    func sendIncrementsSequence() {
        var strategy = BroadcastStrategy()
        let r1 = strategy.prepareSend(activeMembers: [1])
        let r2 = strategy.prepareSend(activeMembers: [1])
        #expect(r1.sequenceNumber == SequenceNumber(0))
        #expect(r2.sequenceNumber == SequenceNumber(1))
    }

    @Test("prepareSend with no active members returns empty targets")
    func sendNoMembers() {
        var strategy = BroadcastStrategy()
        let result = strategy.prepareSend(activeMembers: [])
        #expect(result.targets.isEmpty)
    }

    // MARK: - Receive (deduplication)

    @Test("First arrival of sequence returns .newPacket")
    func firstArrivalNew() {
        var strategy = BroadcastStrategy()
        let result = strategy.processReceive(
            sequenceNumber: SequenceNumber(0),
            payload: [0x01],
            fromMember: 1
        )
        if case .newPacket(let payload, let seq) = result {
            #expect(payload == [0x01])
            #expect(seq == SequenceNumber(0))
        } else {
            Issue.record("Expected newPacket")
        }
    }

    @Test("Second arrival of same sequence returns .duplicate")
    func secondArrivalDuplicate() {
        var strategy = BroadcastStrategy()
        _ = strategy.processReceive(
            sequenceNumber: SequenceNumber(0),
            payload: [0x01], fromMember: 1)
        let result = strategy.processReceive(
            sequenceNumber: SequenceNumber(0),
            payload: [0x01], fromMember: 2)
        if case .duplicate(let seq) = result {
            #expect(seq == SequenceNumber(0))
        } else {
            Issue.record("Expected duplicate")
        }
    }

    @Test("Different sequences both return .newPacket")
    func differentSequencesBothNew() {
        var strategy = BroadcastStrategy()
        let r1 = strategy.processReceive(
            sequenceNumber: SequenceNumber(0),
            payload: [0x01], fromMember: 1)
        let r2 = strategy.processReceive(
            sequenceNumber: SequenceNumber(1),
            payload: [0x02], fromMember: 1)
        if case .newPacket = r1 {
        } else {
            Issue.record("Expected newPacket for seq 0")
        }
        if case .newPacket = r2 {
        } else {
            Issue.record("Expected newPacket for seq 1")
        }
    }

    @Test("duplicatesSuppressed counter increments")
    func duplicatesSuppressedCounter() {
        var strategy = BroadcastStrategy()
        #expect(strategy.duplicatesSuppressed == 0)
        _ = strategy.processReceive(
            sequenceNumber: SequenceNumber(0),
            payload: [0x01], fromMember: 1)
        _ = strategy.processReceive(
            sequenceNumber: SequenceNumber(0),
            payload: [0x01], fromMember: 2)
        #expect(strategy.duplicatesSuppressed == 1)
    }

    @Test("Third link same sequence returns .duplicate")
    func thirdLinkDuplicate() {
        var strategy = BroadcastStrategy()
        _ = strategy.processReceive(
            sequenceNumber: SequenceNumber(0),
            payload: [0x01], fromMember: 1)
        _ = strategy.processReceive(
            sequenceNumber: SequenceNumber(0),
            payload: [0x01], fromMember: 2)
        let result = strategy.processReceive(
            sequenceNumber: SequenceNumber(0),
            payload: [0x01], fromMember: 3)
        if case .duplicate = result {
        } else {
            Issue.record("Expected duplicate from third link")
        }
        #expect(strategy.duplicatesSuppressed == 2)
    }

    // MARK: - Reset

    @Test("reset clears dedup state")
    func resetClearsState() {
        var strategy = BroadcastStrategy()
        _ = strategy.processReceive(
            sequenceNumber: SequenceNumber(0),
            payload: [0x01], fromMember: 1)
        strategy.reset()
        #expect(strategy.duplicatesSuppressed == 0)
    }

    @Test("After reset, same sequence is new again")
    func afterResetSameSequenceIsNew() {
        var strategy = BroadcastStrategy()
        _ = strategy.processReceive(
            sequenceNumber: SequenceNumber(0),
            payload: [0x01], fromMember: 1)
        strategy.reset()
        let result = strategy.processReceive(
            sequenceNumber: SequenceNumber(0),
            payload: [0x01], fromMember: 1)
        if case .newPacket = result {
        } else {
            Issue.record("Expected newPacket after reset")
        }
    }
}
