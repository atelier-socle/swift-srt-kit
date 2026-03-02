// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("RendezvousRole Tests")
struct RendezvousRoleTests {
    @Test("Larger local ID -> initiator")
    func largerLocalIsInitiator() {
        let role = RendezvousRole.determine(localSocketID: 200, remoteSocketID: 100)
        #expect(role == .initiator)
    }

    @Test("Smaller local ID -> responder")
    func smallerLocalIsResponder() {
        let role = RendezvousRole.determine(localSocketID: 100, remoteSocketID: 200)
        #expect(role == .responder)
    }

    @Test("Equal IDs -> nil (collision)")
    func equalIDsCollision() {
        let role = RendezvousRole.determine(localSocketID: 100, remoteSocketID: 100)
        #expect(role == nil)
    }

    @Test("Boundary: max UInt32 vs 0")
    func boundaryMaxVsZero() {
        let role = RendezvousRole.determine(localSocketID: UInt32.max, remoteSocketID: 0)
        #expect(role == .initiator)
    }

    @Test("Boundary: 0 vs max UInt32")
    func boundaryZeroVsMax() {
        let role = RendezvousRole.determine(localSocketID: 0, remoteSocketID: UInt32.max)
        #expect(role == .responder)
    }

    @Test("Boundary: adjacent values 100 vs 101")
    func boundaryAdjacentValues() {
        let role = RendezvousRole.determine(localSocketID: 100, remoteSocketID: 101)
        #expect(role == .responder)
    }

    @Test("Description for initiator")
    func descriptionInitiator() {
        #expect(RendezvousRole.initiator.description == "initiator")
    }

    @Test("Description for responder")
    func descriptionResponder() {
        #expect(RendezvousRole.responder.description == "responder")
    }
}
