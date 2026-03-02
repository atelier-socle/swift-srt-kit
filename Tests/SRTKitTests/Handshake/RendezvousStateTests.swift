// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("RendezvousState Tests")
struct RendezvousStateTests {
    @Test("All 6 states exist")
    func allStatesExist() {
        let states: [RendezvousState] = [
            .idle, .waveahandSent, .conclusionSent, .agreementSent, .done, .failed
        ]
        #expect(states.count == 6)
    }

    @Test("CaseIterable count is 6")
    func caseIterableCount() {
        #expect(RendezvousState.allCases.count == 6)
    }

    @Test("Description for idle")
    func descriptionIdle() {
        #expect(RendezvousState.idle.description == "idle")
    }

    @Test("Description for waveahandSent")
    func descriptionWaveahandSent() {
        #expect(RendezvousState.waveahandSent.description == "waveahandSent")
    }

    @Test("Description for conclusionSent")
    func descriptionConclusionSent() {
        #expect(RendezvousState.conclusionSent.description == "conclusionSent")
    }

    @Test("Description for agreementSent")
    func descriptionAgreementSent() {
        #expect(RendezvousState.agreementSent.description == "agreementSent")
    }

    @Test("Description for done")
    func descriptionDone() {
        #expect(RendezvousState.done.description == "done")
    }

    @Test("Description for failed")
    func descriptionFailed() {
        #expect(RendezvousState.failed.description == "failed")
    }
}
