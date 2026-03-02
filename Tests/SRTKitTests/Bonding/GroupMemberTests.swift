// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("GroupMember Tests")
struct GroupMemberTests {
    @Test("Default weight is 1")
    func defaultWeight() {
        let member = GroupMember(id: 1, host: "10.0.0.1", port: 4200)
        #expect(member.weight == 1)
    }

    @Test("Default status is .pending")
    func defaultStatus() {
        let member = GroupMember(id: 1, host: "10.0.0.1", port: 4200)
        #expect(member.status == .pending)
    }

    @Test("Default estimatedBandwidth is 0")
    func defaultBandwidth() {
        let member = GroupMember(id: 1, host: "10.0.0.1", port: 4200)
        #expect(member.estimatedBandwidth == 0)
    }

    @Test("ID matches init parameter")
    func idMatches() {
        let member = GroupMember(id: 42, host: "10.0.0.1", port: 4200)
        #expect(member.id == 42)
    }

    @Test("Identifiable conformance works")
    func identifiable() {
        let m1 = GroupMember(id: 1, host: "10.0.0.1", port: 4200)
        let m2 = GroupMember(id: 2, host: "10.0.0.2", port: 4200)
        #expect(m1.id != m2.id)
    }

    @Test("Custom weight applied")
    func customWeight() {
        let member = GroupMember(
            id: 1, host: "10.0.0.1", port: 4200, weight: 5)
        #expect(member.weight == 5)
    }
}
