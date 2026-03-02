// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTConnectionState Tests")
struct SRTConnectionStateTests {
    @Test("All states have correct string description")
    func stateDescriptions() {
        #expect(SRTConnectionState.idle.description == "idle")
        #expect(SRTConnectionState.connecting.description == "connecting")
        #expect(SRTConnectionState.handshaking.description == "handshaking")
        #expect(SRTConnectionState.connected.description == "connected")
        #expect(SRTConnectionState.transferring.description == "transferring")
        #expect(SRTConnectionState.closing.description == "closing")
        #expect(SRTConnectionState.closed.description == "closed")
        #expect(SRTConnectionState.broken.description == "broken")
    }

    @Test("isActive true for connected and transferring only")
    func isActive() {
        #expect(SRTConnectionState.connected.isActive)
        #expect(SRTConnectionState.transferring.isActive)
        #expect(!SRTConnectionState.idle.isActive)
        #expect(!SRTConnectionState.connecting.isActive)
        #expect(!SRTConnectionState.handshaking.isActive)
        #expect(!SRTConnectionState.closing.isActive)
        #expect(!SRTConnectionState.closed.isActive)
        #expect(!SRTConnectionState.broken.isActive)
    }

    @Test("isTerminal true for closed and broken only")
    func isTerminal() {
        #expect(SRTConnectionState.closed.isTerminal)
        #expect(SRTConnectionState.broken.isTerminal)
        #expect(!SRTConnectionState.idle.isTerminal)
        #expect(!SRTConnectionState.connecting.isTerminal)
        #expect(!SRTConnectionState.handshaking.isTerminal)
        #expect(!SRTConnectionState.connected.isTerminal)
        #expect(!SRTConnectionState.transferring.isTerminal)
        #expect(!SRTConnectionState.closing.isTerminal)
    }

    @Test("Valid transitions from idle: only connecting")
    func idleTransitions() {
        let valid = SRTConnectionState.idle.validTransitions
        #expect(valid == [.connecting])
    }

    @Test("Valid transitions from connecting: handshaking, broken, closed")
    func connectingTransitions() {
        let valid = SRTConnectionState.connecting.validTransitions
        #expect(valid == [.handshaking, .broken, .closed])
    }

    @Test("Valid transitions from handshaking: connected, broken, closed")
    func handshakingTransitions() {
        let valid = SRTConnectionState.handshaking.validTransitions
        #expect(valid == [.connected, .broken, .closed])
    }

    @Test("Valid transitions from connected: transferring, closing, broken")
    func connectedTransitions() {
        let valid = SRTConnectionState.connected.validTransitions
        #expect(valid == [.transferring, .closing, .broken])
    }

    @Test("Valid transitions from transferring: closing, broken")
    func transferringTransitions() {
        let valid = SRTConnectionState.transferring.validTransitions
        #expect(valid == [.closing, .broken])
    }

    @Test("Valid transitions from closing: closed, broken")
    func closingTransitions() {
        let valid = SRTConnectionState.closing.validTransitions
        #expect(valid == [.closed, .broken])
    }

    @Test("No transitions from closed (terminal)")
    func closedTerminal() {
        #expect(SRTConnectionState.closed.validTransitions.isEmpty)
    }

    @Test("No transitions from broken (terminal)")
    func brokenTerminal() {
        #expect(SRTConnectionState.broken.validTransitions.isEmpty)
    }

    @Test("CaseIterable lists all states")
    func caseIterable() {
        let allCases = SRTConnectionState.allCases
        #expect(allCases.count == 8)
        #expect(allCases.contains(.idle))
        #expect(allCases.contains(.connecting))
        #expect(allCases.contains(.handshaking))
        #expect(allCases.contains(.connected))
        #expect(allCases.contains(.transferring))
        #expect(allCases.contains(.closing))
        #expect(allCases.contains(.closed))
        #expect(allCases.contains(.broken))
    }

    @Test("rawValue matches description")
    func rawValue() {
        for state in SRTConnectionState.allCases {
            #expect(state.rawValue == state.description)
        }
    }
}
