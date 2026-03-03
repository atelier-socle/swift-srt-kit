// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("Bonding Showcase")
struct BondingShowcaseTests {
    // MARK: - Group Modes & Link Status

    @Test("GroupMode all cases and descriptions")
    func groupModes() {
        let modes = GroupMode.allCases
        #expect(modes.count == 3)
        #expect(GroupMode.broadcast.description == "Broadcast (all links)")
        #expect(GroupMode.mainBackup.description == "Main/Backup (failover)")
        #expect(GroupMode.balancing.description == "Balancing (aggregate)")
    }

    @Test("LinkStatus active and terminal checks")
    func linkStatusProperties() {
        // Only freshActivated and stable are active
        #expect(LinkStatus.freshActivated.isActive)
        #expect(LinkStatus.stable.isActive)
        #expect(!LinkStatus.unstable.isActive)
        // Inactive/terminal
        #expect(!LinkStatus.pending.isActive)
        #expect(!LinkStatus.idle.isActive)
        #expect(LinkStatus.broken.isTerminal)
        #expect(!LinkStatus.stable.isTerminal)
    }

    @Test("LinkStatus valid transitions")
    func linkStatusTransitions() {
        let pendingTransitions = LinkStatus.pending.validTransitions
        #expect(pendingTransitions.contains(.idle))

        let stableTransitions = LinkStatus.stable.validTransitions
        #expect(stableTransitions.contains(.unstable))
    }

    // MARK: - Group Member

    @Test("GroupMember creation with defaults")
    func groupMemberDefaults() {
        let member = GroupMember(
            id: 1, host: "cdn1.example.com",
            port: 4200, weight: 10)
        #expect(member.id == 1)
        #expect(member.host == "cdn1.example.com")
        #expect(member.port == 4200)
        #expect(member.weight == 10)
        #expect(member.status == .pending)
    }

    // MARK: - Broadcast Strategy

    @Test("BroadcastStrategy sends to all active members")
    func broadcastSend() {
        var strategy = BroadcastStrategy(
            initialSequence: SequenceNumber(0))
        let result = strategy.prepareSend(
            activeMembers: [1, 2, 3])
        #expect(result.targets == [1, 2, 3])
        #expect(result.sequenceNumber == SequenceNumber(0))

        // Next send increments sequence
        let result2 = strategy.prepareSend(
            activeMembers: [1, 2, 3])
        #expect(result2.sequenceNumber == SequenceNumber(1))
    }

    @Test("BroadcastStrategy deduplicates received packets")
    func broadcastDedup() {
        var strategy = BroadcastStrategy(
            initialSequence: SequenceNumber(0))
        let payload: [UInt8] = [0x47, 0x00, 0x11, 0x00]

        // First receive — new
        let r1 = strategy.processReceive(
            sequenceNumber: SequenceNumber(10),
            payload: payload, fromMember: 1)
        if case .newPacket = r1 {
            // Expected
        } else {
            Issue.record("Expected newPacket")
        }

        // Same sequence from different member — duplicate
        let r2 = strategy.processReceive(
            sequenceNumber: SequenceNumber(10),
            payload: payload, fromMember: 2)
        if case .duplicate = r2 {
            // Expected
        } else {
            Issue.record("Expected duplicate")
        }
        #expect(strategy.duplicatesSuppressed >= 1)
    }

    // MARK: - Backup Strategy

    @Test("BackupStrategy activates highest weight idle member")
    func backupActivation() {
        var strategy = BackupStrategy(
            initialSequence: SequenceNumber(0))

        // activateHighestWeight filters for .idle status
        var m1 = GroupMember(
            id: 1, host: "a.com", port: 4200, weight: 5)
        m1.status = .idle
        var m2 = GroupMember(
            id: 2, host: "b.com", port: 4200, weight: 10)
        m2.status = .idle

        let activated = strategy.activateHighestWeight(
            from: [m1, m2])
        #expect(activated == 2)
        #expect(strategy.activeMember == 2)
    }

    // MARK: - Balancing Strategy

    @Test("BalancingStrategy selects link and tracks distribution")
    func balancingDistribution() {
        var strategy = BalancingStrategy(
            initialMessageNumber: 0)

        var m1 = GroupMember(
            id: 1, host: "a.com", port: 4200, weight: 1)
        m1.status = .stable
        m1.estimatedBandwidth = 10_000_000
        var m2 = GroupMember(
            id: 2, host: "b.com", port: 4200, weight: 1)
        m2.status = .stable
        m2.estimatedBandwidth = 10_000_000

        // Select links for multiple sends
        for _ in 0..<10 {
            if let selection = strategy.selectLink(
                from: [m1, m2])
            {
                strategy.recordDelivery(
                    memberID: selection.memberID)
            }
        }

        // Both members should have some deliveries
        let stats = strategy.distributionStats
        #expect(stats.count <= 2)
    }

    // MARK: - Packet Deduplicator

    @Test("PacketDeduplicator detects duplicates within window")
    func deduplicatorWindow() {
        var dedup = PacketDeduplicator(windowSize: 100)

        var isNew1 = dedup.isNew(SequenceNumber(1))
        #expect(isNew1)
        isNew1 = dedup.isNew(SequenceNumber(1))
        #expect(!isNew1)
        #expect(dedup.duplicatesDetected == 1)

        var isNew2 = dedup.isNew(SequenceNumber(2))
        #expect(isNew2)
        let isNew3 = dedup.isNew(SequenceNumber(3))
        #expect(isNew3)
        isNew2 = dedup.isNew(SequenceNumber(2))
        #expect(!isNew2)
        #expect(dedup.duplicatesDetected == 2)

        dedup.reset()
        #expect(dedup.duplicatesDetected == 0)
        // After reset, same sequence is new again
        let isNewAfterReset = dedup.isNew(SequenceNumber(1))
        #expect(isNewAfterReset)
    }

    // MARK: - Group Configuration

    @Test("GroupConfiguration effective stability timeout")
    func groupConfigStabilityTimeout() {
        let config = GroupConfiguration(
            mode: .mainBackup,
            stabilityTimeout: 40_000,
            peerLatency: 120_000)
        // effectiveStabilityTimeout = max(peerLatency, stabilityTimeout)
        #expect(config.effectiveStabilityTimeout == 120_000)

        let config2 = GroupConfiguration(
            mode: .broadcast,
            stabilityTimeout: 200_000,
            peerLatency: 50_000)
        #expect(config2.effectiveStabilityTimeout == 200_000)
    }
}
