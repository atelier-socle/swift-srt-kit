// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("Handshake Showcase")
struct HandshakeShowcaseTests {
    // MARK: - Configuration

    @Test("HandshakeConfiguration defaults")
    func configurationDefaults() {
        let config = HandshakeConfiguration(localSocketID: 0x1234)
        #expect(config.localSocketID == 0x1234)
        #expect(config.senderTSBPDDelay == 120)
        #expect(config.receiverTSBPDDelay == 120)
        #expect(config.maxTransmissionUnitSize == 1500)
        #expect(config.maxFlowWindowSize == 8192)
        #expect(config.handshakeTimeoutMs == 3000)
        #expect(config.streamID == nil)
        #expect(config.passphrase == nil)
    }

    // MARK: - State Machine

    @Test("HandshakeState cases and descriptions")
    func handshakeStateCases() {
        let allStates = HandshakeState.allCases
        #expect(allStates.count == 7)
        #expect(HandshakeState.idle.description == "idle")
        #expect(HandshakeState.done.description == "done")
        #expect(HandshakeState.failed.description == "failed")
    }

    // MARK: - Caller Handshake

    @Test("CallerHandshake starts in idle then sends induction")
    func callerHandshakeStart() {
        let config = HandshakeConfiguration(
            localSocketID: 0xABCD)
        var caller = CallerHandshake(configuration: config)
        #expect(caller.state == .idle)

        let actions = caller.start()
        #expect(!actions.isEmpty)

        // First action should be sendPacket (induction)
        if case .sendPacket(let packet, _) = actions[0] {
            #expect(
                packet.handshakeType == .induction)
            #expect(packet.srtSocketID == 0xABCD)
        } else {
            Issue.record("Expected sendPacket action")
        }
        #expect(caller.state == .inductionSent)
    }

    @Test("CallerHandshake timeout produces error")
    func callerHandshakeTimeout() {
        let config = HandshakeConfiguration(
            localSocketID: 0x1111)
        var caller = CallerHandshake(configuration: config)
        _ = caller.start()

        let action = caller.timeout()
        if case .error = action {
            // Expected timeout error
        } else {
            Issue.record("Expected error action on timeout")
        }
    }

    // MARK: - Listener Handshake

    @Test("ListenerHandshake processInduction returns response")
    func listenerInduction() {
        let config = HandshakeConfiguration(
            localSocketID: 0x5678)
        let listener = ListenerHandshake(configuration: config)
        #expect(listener.state == .idle)

        // Simulate incoming induction
        let induction = HandshakePacket(
            version: 4,
            handshakeType: .induction,
            srtSocketID: 0xAAAA,
            peerIPAddress: .ipv4(0x7F00_0001))

        let action = listener.processInduction(
            handshake: induction,
            from: .ipv4(0x7F00_0001),
            cookieSecret: Array(repeating: 0xCC, count: 16))

        if case .sendPacket(let response, _) = action {
            // Listener responds with induction containing cookie
            #expect(response.synCookie != 0)
        } else {
            Issue.record("Expected sendPacket response")
        }
    }

    @Test("ListenerHandshake timeout produces error")
    func listenerTimeout() {
        let config = HandshakeConfiguration(
            localSocketID: 0x9999)
        var listener = ListenerHandshake(configuration: config)
        let action = listener.timeout()
        if case .error = action {
            // Expected
        } else {
            Issue.record("Expected error action on timeout")
        }
    }
}
