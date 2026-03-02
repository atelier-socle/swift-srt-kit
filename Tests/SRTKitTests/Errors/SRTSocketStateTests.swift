// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTSocketState Tests")
struct SRTSocketStateTests {
    @Test("All 8 states exist")
    func allCasesCount() {
        #expect(SRTSocketState.allCases.count == 8)
    }

    @Test("Raw value roundtrip for all cases")
    func rawValueRoundtrip() {
        for state in SRTSocketState.allCases {
            let reconstructed = SRTSocketState(rawValue: state.rawValue)
            #expect(reconstructed == state)
        }
    }

    @Test("Idle raw value")
    func idleRawValue() {
        #expect(SRTSocketState.idle.rawValue == "idle")
    }

    @Test("Connected raw value")
    func connectedRawValue() {
        #expect(SRTSocketState.connected.rawValue == "connected")
    }

    @Test("Closed raw value")
    func closedRawValue() {
        #expect(SRTSocketState.closed.rawValue == "closed")
    }

    @Test("Description matches raw value")
    func descriptionMatchesRawValue() {
        for state in SRTSocketState.allCases {
            #expect(state.description == state.rawValue)
        }
    }

    @Test("Invalid raw value returns nil")
    func invalidRawValue() {
        #expect(SRTSocketState(rawValue: "invalid") == nil)
    }

    @Test("Hashable conformance")
    func hashableConformance() {
        let set: Set<SRTSocketState> = [.idle, .connected, .idle]
        #expect(set.count == 2)
    }
}
