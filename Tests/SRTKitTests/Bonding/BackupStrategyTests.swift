// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("BackupStrategy Tests")
struct BackupStrategyTests {
    private func makeMember(
        id: UInt32, status: LinkStatus, weight: Int = 1,
        lastResponse: UInt64? = nil
    ) -> GroupMember {
        var m = GroupMember(
            id: id, host: "10.0.0.\(id)", port: 4200, weight: weight)
        m.status = status
        m.lastResponseTime = lastResponse
        return m
    }

    // MARK: - Activation

    @Test("activateHighestWeight selects highest weight member")
    func activateHighestWeight() {
        var strategy = BackupStrategy()
        let members = [
            makeMember(id: 1, status: .idle, weight: 1),
            makeMember(id: 2, status: .idle, weight: 3),
            makeMember(id: 3, status: .idle, weight: 2)
        ]
        let activated = strategy.activateHighestWeight(from: members)
        #expect(activated == 2)
        #expect(strategy.activeMember == 2)
    }

    @Test("activateHighestWeight with equal weights returns first found")
    func activateEqualWeights() {
        var strategy = BackupStrategy()
        let members = [
            makeMember(id: 1, status: .idle),
            makeMember(id: 2, status: .idle)
        ]
        let activated = strategy.activateHighestWeight(from: members)
        #expect(activated != nil)
    }

    @Test("activateHighestWeight skips non-idle members")
    func activateSkipsNonIdle() {
        var strategy = BackupStrategy()
        let members = [
            makeMember(id: 1, status: .stable, weight: 10),
            makeMember(id: 2, status: .idle, weight: 1)
        ]
        let activated = strategy.activateHighestWeight(from: members)
        #expect(activated == 2)
    }

    @Test("activateHighestWeight with no idle returns nil")
    func activateNoIdle() {
        var strategy = BackupStrategy()
        let members = [
            makeMember(id: 1, status: .broken),
            makeMember(id: 2, status: .stable)
        ]
        let activated = strategy.activateHighestWeight(from: members)
        #expect(activated == nil)
    }

    @Test("activeMember is set after activation")
    func activeMemberAfterActivation() {
        var strategy = BackupStrategy()
        #expect(strategy.activeMember == nil)
        let members = [makeMember(id: 5, status: .idle)]
        _ = strategy.activateHighestWeight(from: members)
        #expect(strategy.activeMember == 5)
    }

    // MARK: - Stability check

    @Test("All stable returns .stable")
    func allStable() {
        var strategy = BackupStrategy()
        _ = strategy.activateHighestWeight(
            from: [makeMember(id: 1, status: .idle)])
        let members = [
            makeMember(
                id: 1, status: .stable, lastResponse: 100_000)
        ]
        let result = strategy.checkStability(
            members: members, currentTime: 110_000,
            stabilityTimeout: 120_000)
        if case .stable = result {
        } else {
            Issue.record("Expected stable")
        }
    }

    @Test("Active member timed out triggers .failover")
    func activeTimedOut() {
        var strategy = BackupStrategy()
        _ = strategy.activateHighestWeight(
            from: [
                makeMember(id: 1, status: .idle),
                makeMember(id: 2, status: .idle)
            ])
        // Member 1 is active, timed out
        let members = [
            makeMember(
                id: 1, status: .unstable, lastResponse: 100_000),
            makeMember(id: 2, status: .idle)
        ]
        let result = strategy.checkStability(
            members: members, currentTime: 300_000,
            stabilityTimeout: 120_000)
        if case .failover(let event) = result {
            #expect(event.fromMember == 1)
            #expect(event.toMember == 2)
        } else {
            Issue.record("Expected failover, got \(result)")
        }
    }

    @Test("Failover selects highest-weight idle backup")
    func failoverSelectsHighestWeight() {
        var strategy = BackupStrategy()
        _ = strategy.activateHighestWeight(
            from: [
                makeMember(id: 1, status: .idle, weight: 3),
                makeMember(id: 2, status: .idle, weight: 1),
                makeMember(id: 3, status: .idle, weight: 2)
            ])
        // Member 1 active, becomes unstable
        let members = [
            makeMember(id: 1, status: .unstable),
            makeMember(id: 2, status: .idle, weight: 1),
            makeMember(id: 3, status: .idle, weight: 2)
        ]
        let result = strategy.checkStability(
            members: members, currentTime: 300_000,
            stabilityTimeout: 0)
        if case .failover(let event) = result {
            #expect(event.toMember == 3)
        } else {
            Issue.record("Expected failover")
        }
    }

    @Test("No backup available returns .allLinksDown")
    func noBackup() {
        var strategy = BackupStrategy()
        _ = strategy.activateHighestWeight(
            from: [makeMember(id: 1, status: .idle)])
        let members = [
            makeMember(id: 1, status: .unstable)
        ]
        let result = strategy.checkStability(
            members: members, currentTime: 300_000,
            stabilityTimeout: 0)
        if case .allLinksDown = result {
        } else {
            Issue.record("Expected allLinksDown")
        }
    }

    // MARK: - Sequence synchronization

    @Test("synchronizeSequence returns group sequence")
    func syncSequence() {
        let strategy = BackupStrategy(
            initialSequence: SequenceNumber(42))
        #expect(
            strategy.synchronizeSequence(for: 1) == SequenceNumber(42))
    }

    @Test("prepareSend returns active member and sequence")
    func prepareSendActive() {
        var strategy = BackupStrategy()
        _ = strategy.activateHighestWeight(
            from: [makeMember(id: 1, status: .idle)])
        let result = strategy.prepareSend()
        #expect(result?.memberID == 1)
        #expect(result?.sequenceNumber == SequenceNumber(0))
    }

    @Test("prepareSend with no active returns nil")
    func prepareSendNoActive() {
        var strategy = BackupStrategy()
        let result = strategy.prepareSend()
        #expect(result == nil)
    }

    @Test("Sequence increments on prepareSend")
    func sequenceIncrementsOnSend() {
        var strategy = BackupStrategy()
        _ = strategy.activateHighestWeight(
            from: [makeMember(id: 1, status: .idle)])
        let r1 = strategy.prepareSend()
        let r2 = strategy.prepareSend()
        #expect(r1?.sequenceNumber == SequenceNumber(0))
        #expect(r2?.sequenceNumber == SequenceNumber(1))
    }

    // MARK: - Failover history

    @Test("failoverCount increments on failover")
    func failoverCountIncrements() {
        var strategy = BackupStrategy()
        #expect(strategy.failoverCount == 0)
        _ = strategy.activateHighestWeight(
            from: [
                makeMember(id: 1, status: .idle),
                makeMember(id: 2, status: .idle)
            ])
        let members = [
            makeMember(id: 1, status: .unstable),
            makeMember(id: 2, status: .idle)
        ]
        _ = strategy.checkStability(
            members: members, currentTime: 300_000,
            stabilityTimeout: 0)
        #expect(strategy.failoverCount == 1)
    }

    @Test("failoverHistory records events")
    func failoverHistoryRecords() {
        var strategy = BackupStrategy()
        _ = strategy.activateHighestWeight(
            from: [
                makeMember(id: 1, status: .idle),
                makeMember(id: 2, status: .idle)
            ])
        _ = strategy.checkStability(
            members: [
                makeMember(id: 1, status: .unstable),
                makeMember(id: 2, status: .idle)
            ],
            currentTime: 300_000, stabilityTimeout: 0)
        #expect(strategy.failoverHistory.count == 1)
        #expect(strategy.failoverHistory[0].fromMember == 1)
        #expect(strategy.failoverHistory[0].toMember == 2)
    }

    @Test("Multiple failovers tracked")
    func multipleFailoversTracked() {
        var strategy = BackupStrategy()
        _ = strategy.activateHighestWeight(
            from: [
                makeMember(id: 1, status: .idle),
                makeMember(id: 2, status: .idle),
                makeMember(id: 3, status: .idle)
            ])
        // First failover: 1 → 2
        _ = strategy.checkStability(
            members: [
                makeMember(id: 1, status: .unstable),
                makeMember(id: 2, status: .idle),
                makeMember(id: 3, status: .idle)
            ],
            currentTime: 300_000, stabilityTimeout: 0)
        // Second failover: 2 → 3
        _ = strategy.checkStability(
            members: [
                makeMember(id: 1, status: .broken),
                makeMember(id: 2, status: .unstable),
                makeMember(id: 3, status: .idle)
            ],
            currentTime: 400_000, stabilityTimeout: 0)
        #expect(strategy.failoverCount == 2)
    }
}
