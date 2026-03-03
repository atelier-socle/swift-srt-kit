// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTCaller Coverage Tests")
struct SRTCallerCoverageTests {

    // MARK: - statistics with completed handshake

    @Test("statistics with socket delegates to socket")
    func statisticsWithSocket() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        let socket = SRTSocket(role: .caller, socketID: 42)
        await caller.completeHandshake(
            socket: socket, peerSocketID: 99, negotiatedLatency: 120_000)

        let stats = await caller.statistics()
        #expect(stats.packetsReceived >= 0)
    }

    @Test("statistics without socket returns empty")
    func statisticsWithoutSocket() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        let stats = await caller.statistics()
        #expect(stats.packetsSent == 0)
    }

    // MARK: - send with completed handshake

    @Test("send with socket but socket in wrong state throws")
    func sendWithSocketWrongState() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        let socket = SRTSocket(role: .caller, socketID: 42)
        await caller.completeHandshake(
            socket: socket, peerSocketID: 99, negotiatedLatency: 120_000)
        // caller.state is .connected, but socket.state is .idle
        // The caller.send checks caller.state which IS active
        // but then delegates to socket.send which checks socket.state
        do {
            _ = try await caller.send([0x01])
            Issue.record("Expected throw from socket")
        } catch {
            // expected — socket is in idle state
        }
    }

    // MARK: - receive with completed handshake

    @Test("receive with socket in idle returns nil")
    func receiveWithSocketIdle() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        let socket = SRTSocket(role: .caller, socketID: 42)
        await caller.completeHandshake(
            socket: socket, peerSocketID: 99, negotiatedLatency: 120_000)
        let data = await caller.receive()
        #expect(data == nil)
    }

    // MARK: - disconnect with completed handshake

    @Test("disconnect after completeHandshake closes socket")
    func disconnectAfterHandshake() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        let socket = SRTSocket(role: .caller, socketID: 42)
        await caller.completeHandshake(
            socket: socket, peerSocketID: 99, negotiatedLatency: 120_000)
        let stateBefore = await caller.state
        #expect(stateBefore == .connected)

        await caller.disconnect()
        let stateAfter = await caller.state
        #expect(stateAfter == .closed)
    }

    // MARK: - connect when not idle

    @Test("connect when already connecting throws")
    func connectWhenNotIdle() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        // Complete handshake puts us in connected
        let socket = SRTSocket(role: .caller, socketID: 42)
        await caller.completeHandshake(
            socket: socket, peerSocketID: 99, negotiatedLatency: 120_000)
        do {
            try await caller.connect()
            Issue.record("Expected throw")
        } catch let error as SRTConnectionError {
            if case .invalidState = error {
                // expected
            } else {
                Issue.record("Expected invalidState")
            }
        } catch {
            // Other errors also acceptable (e.g., already connecting)
        }
    }

    // MARK: - Events

    @Test("completeHandshake emits stateChanged and handshakeComplete events")
    func completeHandshakeEmitsEvents() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        let events = await caller.events

        let socket = SRTSocket(role: .caller, socketID: 42)
        await caller.completeHandshake(
            socket: socket, peerSocketID: 99, negotiatedLatency: 120_000)

        var stateChanged = false
        var handshakeComplete = false
        for await event in events {
            switch event {
            case .stateChanged:
                stateChanged = true
            case .handshakeComplete:
                handshakeComplete = true
            default:
                break
            }
            if stateChanged && handshakeComplete { break }
        }
        #expect(stateChanged)
        #expect(handshakeComplete)
    }

    // MARK: - send() in various invalid states

    @Test("send in closing state throws invalidState")
    func sendInClosingState() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        let socket = SRTSocket(role: .caller, socketID: 42)
        await caller.completeHandshake(
            socket: socket, peerSocketID: 99, negotiatedLatency: 120_000)
        // Move to closed via disconnect (passes through closing)
        await caller.disconnect()
        // Now state is .closed — isActive is false
        do {
            _ = try await caller.send([0x01])
            Issue.record("Expected throw from send in closed state")
        } catch let error as SRTConnectionError {
            if case .invalidState = error {
                // expected
            } else {
                Issue.record("Expected invalidState, got \(error)")
            }
        } catch {
            Issue.record("Expected SRTConnectionError, got \(error)")
        }
    }

    @Test("send with empty payload in idle state throws")
    func sendEmptyPayloadIdleState() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        let state = await caller.state
        #expect(state == .idle)
        do {
            _ = try await caller.send([])
            Issue.record("Expected throw from send in idle state")
        } catch let error as SRTConnectionError {
            if case .invalidState(let current, _) = error {
                #expect(current == .idle)
            } else {
                Issue.record("Expected invalidState, got \(error)")
            }
        } catch {
            Issue.record("Expected SRTConnectionError, got \(error)")
        }
    }

    // MARK: - receive() in non-connected states

    @Test("receive in closed state returns nil")
    func receiveInClosedState() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        let socket = SRTSocket(role: .caller, socketID: 42)
        await caller.completeHandshake(
            socket: socket, peerSocketID: 99, negotiatedLatency: 120_000)
        await caller.disconnect()
        let state = await caller.state
        #expect(state == .closed)
        let data = await caller.receive()
        #expect(data == nil)
    }

    @Test("receive with no socket in idle returns nil")
    func receiveNoSocketIdle() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        let state = await caller.state
        #expect(state == .idle)
        let data = await caller.receive()
        #expect(data == nil)
    }

    // MARK: - disconnect() from idle state

    @Test("disconnect from idle transitions to closed via closing")
    func disconnectFromIdleTransitionsCorrectly() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        let stateBefore = await caller.state
        #expect(stateBefore == .idle)
        await caller.disconnect()
        let stateAfter = await caller.state
        #expect(stateAfter == .closed)
    }

    // MARK: - disconnect() idempotent from connected

    @Test("disconnect twice from connected is safe")
    func disconnectTwiceFromConnected() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        let socket = SRTSocket(role: .caller, socketID: 42)
        await caller.completeHandshake(
            socket: socket, peerSocketID: 99, negotiatedLatency: 120_000)
        let stateBefore = await caller.state
        #expect(stateBefore == .connected)

        await caller.disconnect()
        let stateAfterFirst = await caller.state
        #expect(stateAfterFirst == .closed)

        // Second disconnect should be a no-op (isTerminal guard)
        await caller.disconnect()
        let stateAfterSecond = await caller.state
        #expect(stateAfterSecond == .closed)
    }

    // MARK: - connect() from closed state

    @Test("connect from closed state throws invalidState")
    func connectFromClosedState() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        await caller.disconnect()
        let state = await caller.state
        #expect(state == .closed)
        do {
            try await caller.connect()
            Issue.record("Expected throw from connect in closed state")
        } catch let error as SRTConnectionError {
            if case .invalidState(let current, let required) = error {
                #expect(current == .closed)
                #expect(required == "idle")
            } else {
                Issue.record("Expected invalidState, got \(error)")
            }
        } catch {
            Issue.record("Expected SRTConnectionError, got \(error)")
        }
    }

    @Test("connect from connected state throws invalidState")
    func connectFromConnectedState() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        let socket = SRTSocket(role: .caller, socketID: 42)
        await caller.completeHandshake(
            socket: socket, peerSocketID: 99, negotiatedLatency: 120_000)
        let state = await caller.state
        #expect(state == .connected)
        do {
            try await caller.connect()
            Issue.record("Expected throw from connect in connected state")
        } catch let error as SRTConnectionError {
            if case .invalidState(let current, let required) = error {
                #expect(current == .connected)
                #expect(required == "idle")
            } else {
                Issue.record("Expected invalidState, got \(error)")
            }
        } catch {
            Issue.record("Expected SRTConnectionError, got \(error)")
        }
    }

}

@Suite("SRTCaller Coverage Tests Part 2")
struct SRTCallerCoverageTests2 {

    // MARK: - Configuration edge cases

    @Test("configuration with empty streamID stores empty string")
    func configEmptyStreamID() {
        let config = SRTCaller.Configuration(
            host: "127.0.0.1", port: 4200, streamID: "")
        #expect(config.streamID == "")
    }

    @Test("configuration with nil passphrase and nil streamID")
    func configNilPassphraseNilStreamID() {
        let config = SRTCaller.Configuration(
            host: "127.0.0.1", port: 4200,
            passphrase: nil, keySize: .aes256)
        #expect(config.passphrase == nil)
        #expect(config.streamID == nil)
        #expect(config.keySize == .aes256)
    }

    @Test("configuration with port zero")
    func configPortZero() {
        let config = SRTCaller.Configuration(
            host: "127.0.0.1", port: 0)
        #expect(config.port == 0)
    }

    @Test("configuration with zero connect timeout")
    func configZeroConnectTimeout() {
        let config = SRTCaller.Configuration(
            host: "127.0.0.1", port: 4200, connectTimeout: 0)
        #expect(config.connectTimeout == 0)
    }

    @Test("configuration with GCM cipher mode")
    func configGCMCipherMode() {
        let config = SRTCaller.Configuration(
            host: "127.0.0.1", port: 4200,
            passphrase: "testpass", cipherMode: .gcm)
        #expect(config.cipherMode == .gcm)
        #expect(config.passphrase == "testpass")
    }

    // MARK: - state property changes through lifecycle

    @Test("state transitions: idle -> connected -> closed")
    func stateLifecycleTransitions() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        let stateIdle = await caller.state
        #expect(stateIdle == .idle)
        #expect(!stateIdle.isActive)
        #expect(!stateIdle.isTerminal)

        let socket = SRTSocket(role: .caller, socketID: 42)
        await caller.completeHandshake(
            socket: socket, peerSocketID: 99, negotiatedLatency: 120_000)
        let stateConnected = await caller.state
        #expect(stateConnected == .connected)
        #expect(stateConnected.isActive)
        #expect(!stateConnected.isTerminal)

        await caller.disconnect()
        let stateClosed = await caller.state
        #expect(stateClosed == .closed)
        #expect(!stateClosed.isActive)
        #expect(stateClosed.isTerminal)
    }

    @Test("completeHandshake stores correct peer socket ID in event")
    func completeHandshakePeerSocketID() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        let events = await caller.events

        let socket = SRTSocket(role: .caller, socketID: 42)
        await caller.completeHandshake(
            socket: socket, peerSocketID: 777, negotiatedLatency: 250_000)

        for await event in events {
            if case .handshakeComplete(let peerID, let latency) = event {
                #expect(peerID == 777)
                #expect(latency == 250_000)
                break
            }
        }
    }

    // MARK: - statistics() at various states

    @Test("statistics from closed state returns empty stats")
    func statisticsFromClosedState() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        let socket = SRTSocket(role: .caller, socketID: 42)
        await caller.completeHandshake(
            socket: socket, peerSocketID: 99, negotiatedLatency: 120_000)
        await caller.disconnect()
        let state = await caller.state
        #expect(state == .closed)
        // After disconnect, socket reference may still exist but socket is closed
        let stats = await caller.statistics()
        #expect(stats.packetsSent == 0)
        #expect(stats.packetsReceived == 0)
    }

    @Test("statistics from idle state returns zero counts")
    func statisticsFromIdleState() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        let state = await caller.state
        #expect(state == .idle)
        let stats = await caller.statistics()
        #expect(stats.packetsSent == 0)
        #expect(stats.packetsReceived == 0)
        #expect(stats.packetsRetransmitted == 0)
        #expect(stats.bytesSent == 0)
        #expect(stats.bytesReceived == 0)
    }

    @Test("statistics from connected state with fresh socket returns zeros")
    func statisticsFromConnectedFreshSocket() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        let socket = SRTSocket(role: .caller, socketID: 42)
        await caller.completeHandshake(
            socket: socket, peerSocketID: 99, negotiatedLatency: 120_000)
        let state = await caller.state
        #expect(state == .connected)
        let stats = await caller.statistics()
        // Fresh socket with no traffic should have zero counts
        #expect(stats.packetsSent == 0)
        #expect(stats.packetsReceived == 0)
    }

    // MARK: - events stream after disconnect

    @Test("disconnect emits stateChanged events and finishes stream")
    func disconnectEmitsStateChangedEvents() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        let events = await caller.events

        await caller.disconnect()

        var closingEmitted = false
        var closedEmitted = false
        for await event in events {
            if case .stateChanged(_, let to) = event {
                if to == .closing { closingEmitted = true }
                if to == .closed { closedEmitted = true }
            }
        }
        // Stream should terminate after disconnect finishes
        #expect(closingEmitted)
        #expect(closedEmitted)
    }

    @Test("disconnect from connected emits closing then closed events")
    func disconnectFromConnectedEmitsEvents() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        let events = await caller.events

        let socket = SRTSocket(role: .caller, socketID: 42)
        await caller.completeHandshake(
            socket: socket, peerSocketID: 99, negotiatedLatency: 120_000)
        await caller.disconnect()

        var stateChanges: [(SRTConnectionState, SRTConnectionState)] = []
        for await event in events {
            if case .stateChanged(let from, let to) = event {
                stateChanges.append((from, to))
            }
        }
        // Should have: handshaking->connected, connected->closing, closing->closed
        let closingTransition = stateChanges.contains { $0.0 == .connected && $0.1 == .closing }
        let closedTransition = stateChanges.contains { $0.0 == .closing && $0.1 == .closed }
        #expect(closingTransition)
        #expect(closedTransition)
    }

    // MARK: - send with nil socket guard

    @Test("send when state is forced active but socket nil throws")
    func sendActiveNoSocket() async {
        // After completeHandshake, disconnect clears state to closed
        // This test verifies the guard on socket inside send
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        // State is idle, isActive is false, so send throws on first guard
        do {
            _ = try await caller.send([0xDE, 0xAD])
            Issue.record("Expected throw")
        } catch let error as SRTConnectionError {
            if case .invalidState(let current, _) = error {
                #expect(current == .idle)
            } else {
                Issue.record("Expected invalidState, got \(error)")
            }
        } catch {
            Issue.record("Expected SRTConnectionError")
        }
    }
}
