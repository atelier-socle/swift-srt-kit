// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("HandshakeState Tests")
struct HandshakeStateTests {
    @Test("All 7 states exist")
    func allStatesExist() {
        #expect(HandshakeState.allCases.count == 7)
    }

    @Test("Description matches raw value")
    func descriptionMatchesRawValue() {
        for state in HandshakeState.allCases {
            #expect(state.description == state.rawValue)
        }
    }

    @Test("Idle state raw value")
    func idleRawValue() {
        #expect(HandshakeState.idle.rawValue == "idle")
    }

    @Test("InductionSent raw value")
    func inductionSentRawValue() {
        #expect(HandshakeState.inductionSent.rawValue == "inductionSent")
    }

    @Test("Done raw value")
    func doneRawValue() {
        #expect(HandshakeState.done.rawValue == "done")
    }

    @Test("Failed raw value")
    func failedRawValue() {
        #expect(HandshakeState.failed.rawValue == "failed")
    }

    @Test("Raw value roundtrip for all states")
    func rawValueRoundtrip() {
        for state in HandshakeState.allCases {
            let recovered = HandshakeState(rawValue: state.rawValue)
            #expect(recovered == state)
        }
    }
}
