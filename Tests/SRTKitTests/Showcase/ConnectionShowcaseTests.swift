// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("Connection Showcase")
struct ConnectionShowcaseTests {
    // MARK: - Connection State

    @Test("SRTConnectionState full lifecycle")
    func connectionStateLifecycle() {
        let lifecycle: [SRTConnectionState] = [
            .idle, .connecting, .handshaking,
            .connected, .transferring, .closing, .closed
        ]
        for state in lifecycle {
            _ = state.description
        }
        // Terminal states
        #expect(SRTConnectionState.closed.isTerminal)
        #expect(SRTConnectionState.broken.isTerminal)
        #expect(!SRTConnectionState.transferring.isTerminal)
    }

    @Test("SRTConnectionState active states")
    func connectionStateActive() {
        // Only connected and transferring are active
        #expect(!SRTConnectionState.idle.isActive)
        #expect(!SRTConnectionState.connecting.isActive)
        #expect(!SRTConnectionState.handshaking.isActive)
        #expect(SRTConnectionState.connected.isActive)
        #expect(SRTConnectionState.transferring.isActive)
        #expect(!SRTConnectionState.closed.isActive)
        #expect(!SRTConnectionState.broken.isActive)
    }

    @Test("SRTConnectionState valid transitions")
    func connectionStateTransitions() {
        let idleTransitions = SRTConnectionState.idle.validTransitions
        #expect(idleTransitions.contains(.connecting))
        #expect(!idleTransitions.contains(.transferring))

        let connectingTransitions =
            SRTConnectionState.connecting.validTransitions
        #expect(connectingTransitions.contains(.handshaking))

        // Terminal states have no valid transitions
        #expect(SRTConnectionState.closed.validTransitions.isEmpty)
        #expect(SRTConnectionState.broken.validTransitions.isEmpty)
    }

    @Test("SRTConnectionState all cases enumerated")
    func connectionStateAllCases() {
        let allStates = SRTConnectionState.allCases
        #expect(allStates.count == 8)
        // Check descriptions match raw values
        for state in allStates {
            #expect(state.description == state.rawValue)
        }
    }

    // MARK: - Caller Configuration

    @Test("SRTCaller.Configuration defaults")
    func callerConfigurationDefaults() {
        let config = SRTCaller.Configuration(
            host: "srt.example.com", port: 4200)
        #expect(config.host == "srt.example.com")
        #expect(config.port == 4200)
        #expect(config.streamID == nil)
        #expect(config.passphrase == nil)
        #expect(config.keySize == .aes128)
        #expect(config.cipherMode == .ctr)
    }

    // MARK: - Listener Configuration

    @Test("SRTListener.Configuration defaults")
    func listenerConfigurationDefaults() {
        let config = SRTListener.Configuration(port: 4200)
        #expect(config.host == "0.0.0.0")
        #expect(config.port == 4200)
        #expect(config.backlog == 5)
        #expect(config.passphrase == nil)
    }
}
