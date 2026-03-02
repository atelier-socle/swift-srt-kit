// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("SRTSocket Tests")
struct SRTSocketTests {
    // MARK: - Initial state

    @Test("Initial state is idle")
    func initialStateIdle() async {
        let socket = SRTSocket(role: .caller, socketID: 1)
        let state = await socket.state
        #expect(state == .idle)
    }

    @Test("Socket ID is stored correctly")
    func socketIDStored() async {
        let socket = SRTSocket(role: .caller, socketID: 42)
        let id = await socket.socketID
        #expect(id == 42)
    }

    @Test("Peer socket ID is nil initially")
    func peerSocketIDNil() async {
        let socket = SRTSocket(role: .listener, socketID: 1)
        let peerID = await socket.peerSocketID
        #expect(peerID == nil)
    }

    // MARK: - State transitions

    @Test("send in idle throws invalidState")
    func sendInIdleThrows() async {
        let socket = SRTSocket(role: .caller, socketID: 1)
        do {
            _ = try await socket.send([0x01])
            Issue.record("Expected throw")
        } catch let error as SRTConnectionError {
            if case .invalidState(let current, _) = error {
                #expect(current == .idle)
            } else {
                Issue.record("Expected invalidState error")
            }
        } catch {
            Issue.record("Expected SRTConnectionError")
        }
    }

    @Test("receive in idle returns nil")
    func receiveInIdleReturnsNil() async {
        let socket = SRTSocket(role: .caller, socketID: 1)
        let data = await socket.receive()
        #expect(data == nil)
    }

    @Test("transitionTo valid state succeeds")
    func validTransition() async {
        let socket = SRTSocket(role: .caller, socketID: 1)
        let result = await socket.transitionTo(.connecting)
        #expect(result == true)
        let state = await socket.state
        #expect(state == .connecting)
    }

    @Test("transitionTo invalid state fails")
    func invalidTransition() async {
        let socket = SRTSocket(role: .caller, socketID: 1)
        // idle → connected is not valid (must go through connecting first)
        let result = await socket.transitionTo(.connected)
        #expect(result == false)
        let state = await socket.state
        #expect(state == .idle)
    }

    @Test("close transitions to closing then closed")
    func closeTransitions() async {
        let socket = SRTSocket(role: .caller, socketID: 1)
        // Move to a state where close is valid
        await socket.transitionTo(.connecting)
        await socket.transitionTo(.handshaking)
        await socket.transitionTo(.connected)

        await socket.close()
        let state = await socket.state
        #expect(state == .closing || state == .closed)
    }

    @Test("close on terminal state is no-op")
    func closeOnTerminalNoOp() async {
        let socket = SRTSocket(role: .caller, socketID: 1)
        await socket.transitionTo(.connecting)
        await socket.transitionTo(.handshaking)
        await socket.transitionTo(.connected)
        await socket.transitionTo(.broken)

        let stateBefore = await socket.state
        #expect(stateBefore == .broken)
        await socket.close()
        let stateAfter = await socket.state
        #expect(stateAfter == .broken)
    }

    // MARK: - Handshake completion

    @Test("handshakeCompleted sets peer socket ID")
    func handshakeCompletedSetsPeer() async {
        let socket = SRTSocket(role: .caller, socketID: 1)
        await socket.transitionTo(.connecting)
        await socket.transitionTo(.handshaking)
        await socket.transitionTo(.connected)

        await socket.handshakeCompleted(
            peerSocketID: 99, negotiatedLatency: 120_000)
        let peerID = await socket.peerSocketID
        #expect(peerID == 99)
    }

    // MARK: - Tick

    @Test("tick in connected state does not crash")
    func tickInConnectedState() async throws {
        let socket = SRTSocket(role: .caller, socketID: 1)
        await socket.transitionTo(.connecting)
        await socket.transitionTo(.handshaking)
        await socket.transitionTo(.connected)

        // tick should not throw
        try await socket.tick(currentTime: 1_000_000)
    }

    // MARK: - Role

    @Test("Role stored correctly for caller")
    func roleCaller() async {
        let socket = SRTSocket(role: .caller, socketID: 1)
        let role = await socket.role
        #expect(role == .caller)
    }

    @Test("Role stored correctly for listener")
    func roleListener() async {
        let socket = SRTSocket(role: .listener, socketID: 1)
        let role = await socket.role
        #expect(role == .listener)
    }

    @Test("Role stored correctly for rendezvous")
    func roleRendezvous() async {
        let socket = SRTSocket(role: .rendezvous, socketID: 1)
        let role = await socket.role
        #expect(role == .rendezvous)
    }

    // MARK: - Events

    @Test("Events stream is available")
    func eventsStreamAvailable() async {
        let socket = SRTSocket(role: .caller, socketID: 1)
        let events = await socket.events
        // Just verify we can get the stream (it's an AsyncStream)
        _ = events
    }

    @Test("State transition emits event")
    func stateTransitionEmitsEvent() async {
        let socket = SRTSocket(role: .caller, socketID: 1)
        let events = await socket.events
        await socket.transitionTo(.connecting)

        // Collect first event
        var eventReceived = false
        for await event in events {
            if case .stateChanged(let from, let to) = event {
                #expect(from == .idle)
                #expect(to == .connecting)
                eventReceived = true
            }
            break
        }
        #expect(eventReceived)
    }
}
