// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("BalancingStrategy Tests")
struct BalancingStrategyTests {
    private func makeMember(
        id: UInt32, weight: Int = 1,
        bandwidth: UInt64 = 1_000_000, load: Int = 0
    ) -> GroupMember {
        var m = GroupMember(
            id: id, host: "10.0.0.\(id)", port: 4200, weight: weight)
        m.status = .stable
        m.estimatedBandwidth = bandwidth
        m.currentLoad = load
        return m
    }

    // MARK: - Link selection

    @Test("selectLink with 1 member selects that member")
    func selectSingleMember() {
        var strategy = BalancingStrategy()
        let selection = strategy.selectLink(
            from: [makeMember(id: 1)])
        #expect(selection?.memberID == 1)
    }

    @Test("selectLink with different weights prefers higher weight")
    func selectHigherWeight() {
        var strategy = BalancingStrategy()
        let selection = strategy.selectLink(
            from: [
                makeMember(id: 1, weight: 1, bandwidth: 1_000_000),
                makeMember(id: 2, weight: 3, bandwidth: 1_000_000)
            ])
        #expect(selection?.memberID == 2)
    }

    @Test("selectLink with equal weight prefers higher bandwidth")
    func selectHigherBandwidth() {
        var strategy = BalancingStrategy()
        let selection = strategy.selectLink(
            from: [
                makeMember(id: 1, weight: 1, bandwidth: 1_000_000),
                makeMember(id: 2, weight: 1, bandwidth: 5_000_000)
            ])
        #expect(selection?.memberID == 2)
    }

    @Test("selectLink with equal weight and BW prefers lower load")
    func selectLowerLoad() {
        var strategy = BalancingStrategy()
        let selection = strategy.selectLink(
            from: [
                makeMember(
                    id: 1, weight: 1, bandwidth: 1_000_000, load: 10),
                makeMember(
                    id: 2, weight: 1, bandwidth: 1_000_000, load: 1)
            ])
        #expect(selection?.memberID == 2)
    }

    @Test("selectLink with no active members returns nil")
    func selectNoMembers() {
        var strategy = BalancingStrategy()
        let selection = strategy.selectLink(from: [])
        #expect(selection == nil)
    }

    @Test("messageNumber increments on each selection")
    func messageNumberIncrements() {
        var strategy = BalancingStrategy()
        let members = [makeMember(id: 1)]
        let s1 = strategy.selectLink(from: members)
        let s2 = strategy.selectLink(from: members)
        #expect(s1?.messageNumber == 0)
        #expect(s2?.messageNumber == 1)
    }

    // MARK: - Distribution

    @Test("distributionStats tracks per-member counts")
    func distributionStatsTracked() {
        var strategy = BalancingStrategy()
        let members = [makeMember(id: 1)]
        _ = strategy.selectLink(from: members)
        _ = strategy.selectLink(from: members)
        _ = strategy.selectLink(from: members)
        #expect(strategy.distributionStats[1] == 3)
    }

    // MARK: - Receive

    @Test("In-order message delivers immediately")
    func inOrderDeliversImmediately() {
        var strategy = BalancingStrategy()
        let delivered = strategy.processReceive(
            messageNumber: 0, payload: [0xAA], fromMember: 1)
        #expect(delivered.count == 1)
        #expect(delivered[0] == [0xAA])
    }

    @Test("Out-of-order messages buffered until gap fills")
    func outOfOrderBuffered() {
        var strategy = BalancingStrategy()
        // Receive msg 1 first (gap at 0)
        let r1 = strategy.processReceive(
            messageNumber: 1, payload: [0xBB], fromMember: 2)
        #expect(r1.isEmpty)

        // Receive msg 0 (fills gap, delivers 0 and 1)
        let r0 = strategy.processReceive(
            messageNumber: 0, payload: [0xAA], fromMember: 1)
        #expect(r0.count == 2)
        #expect(r0[0] == [0xAA])
        #expect(r0[1] == [0xBB])
    }

    @Test("processReceive delivers consecutive buffered messages")
    func consecutiveBufferedDelivery() {
        var strategy = BalancingStrategy()
        // Buffer msgs 1, 2, 3 (gap at 0)
        _ = strategy.processReceive(
            messageNumber: 1, payload: [0x01], fromMember: 1)
        _ = strategy.processReceive(
            messageNumber: 2, payload: [0x02], fromMember: 2)
        _ = strategy.processReceive(
            messageNumber: 3, payload: [0x03], fromMember: 1)

        // Fill gap at 0 → delivers 0, 1, 2, 3
        let delivered = strategy.processReceive(
            messageNumber: 0, payload: [0x00], fromMember: 2)
        #expect(delivered.count == 4)
    }

    @Test("reset clears distribution stats")
    func resetClearsStats() {
        var strategy = BalancingStrategy()
        let members = [makeMember(id: 1)]
        _ = strategy.selectLink(from: members)
        strategy.reset()
        #expect(strategy.distributionStats.isEmpty)
    }
}
