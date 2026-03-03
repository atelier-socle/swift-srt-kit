// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTCaller Coverage Tests Part 3")
struct SRTCallerCoverageTests3 {

    /// Helper: create a caller with default config.
    private func makeCaller() -> SRTCaller {
        SRTCaller(configuration: .init(host: "127.0.0.1", port: 4200))
    }

    /// Helper: create a socket transitioned to .connected state.
    private func makeConnectedSocket(
        socketID: UInt32 = 42
    ) async -> SRTSocket {
        let socket = SRTSocket(role: .caller, socketID: socketID)
        await socket.transitionTo(.connecting)
        await socket.transitionTo(.handshaking)
        await socket.transitionTo(.connected)
        return socket
    }

    // MARK: - send() delegates to socket after completeHandshake

    @Test("send delegates to socket after completeHandshake returns byte count")
    func sendDelegatesToSocket() async throws {
        let caller = makeCaller()
        let socket = await makeConnectedSocket()
        await caller.completeHandshake(
            socket: socket, peerSocketID: 99, negotiatedLatency: 120_000)

        let state = await caller.state
        #expect(state == .connected)

        let payload: [UInt8] = [0xCA, 0xFE, 0xBA, 0xBE]
        let byteCount = try await caller.send(payload)
        #expect(byteCount == payload.count)
    }

    // MARK: - receive() returns nil when socket has no data

    @Test("receive returns nil when socket has no data and is not active")
    func receiveReturnsNilNoData() async {
        let caller = makeCaller()
        let socket = SRTSocket(role: .caller, socketID: 42)
        await caller.completeHandshake(
            socket: socket, peerSocketID: 99, negotiatedLatency: 120_000)
        // Socket is in .idle state (not active), so receive returns nil
        let data = await caller.receive()
        #expect(data == nil)
    }

    // MARK: - disconnect from transferring state

    @Test("disconnect from transferring state closes cleanly")
    func disconnectFromTransferring() async throws {
        let caller = makeCaller()
        let socket = await makeConnectedSocket()
        await caller.completeHandshake(
            socket: socket, peerSocketID: 99, negotiatedLatency: 120_000)

        // Send data to trigger socket transition to transferring
        let payload: [UInt8] = [0x01, 0x02, 0x03]
        _ = try await caller.send(payload)

        await caller.disconnect()
        let state = await caller.state
        #expect(state == .closed)
    }

    // MARK: - disconnect from connecting-like state

    @Test("disconnect from idle state before any handshake")
    func disconnectFromIdleState() async {
        let caller = makeCaller()
        let stateBefore = await caller.state
        #expect(stateBefore == .idle)

        await caller.disconnect()
        let stateAfter = await caller.state
        #expect(stateAfter == .closed)
    }

    // MARK: - statistics after completeHandshake

    @Test("statistics after completeHandshake returns valid snapshot")
    func statisticsAfterCompleteHandshake() async {
        let caller = makeCaller()
        let socket = await makeConnectedSocket()
        await caller.completeHandshake(
            socket: socket, peerSocketID: 99, negotiatedLatency: 120_000)

        let stats = await caller.statistics()
        #expect(stats.packetsSent == 0)
        #expect(stats.packetsReceived == 0)
        #expect(stats.packetsRetransmitted == 0)
    }

    // MARK: - send after completeHandshake then tick

    @Test("send data then tick exercises pipeline")
    func sendThenTick() async throws {
        let caller = makeCaller()
        let socket = await makeConnectedSocket()
        await caller.completeHandshake(
            socket: socket, peerSocketID: 99, negotiatedLatency: 120_000)

        let payload: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
        let sent = try await caller.send(payload)
        #expect(sent == 4)

        // Tick the socket to drive pipeline processing
        let currentTime: UInt64 = 1_000_000
        try await socket.tick(currentTime: currentTime)

        let stats = await caller.statistics()
        // After send + tick, packetsSent should be recorded
        #expect(stats.packetsSent >= 1)
    }

    // MARK: - events stream yields connected event after completeHandshake

    @Test("events stream yields connected event after completeHandshake")
    func eventsStreamYieldsConnected() async {
        let caller = makeCaller()
        let events = await caller.events

        let socket = await makeConnectedSocket()
        await caller.completeHandshake(
            socket: socket, peerSocketID: 55, negotiatedLatency: 80_000)
        // Finish events by disconnecting so the stream terminates
        await caller.disconnect()

        var sawStateChangedToConnected = false
        var sawHandshakeComplete = false
        var handshakePeerID: UInt32 = 0
        var handshakeLatency: UInt64 = 0

        for await event in events {
            switch event {
            case .stateChanged(_, let to) where to == .connected:
                sawStateChangedToConnected = true
            case .handshakeComplete(let peerID, let latency):
                sawHandshakeComplete = true
                handshakePeerID = peerID
                handshakeLatency = latency
            default:
                break
            }
        }

        #expect(sawStateChangedToConnected)
        #expect(sawHandshakeComplete)
        #expect(handshakePeerID == 55)
        #expect(handshakeLatency == 80_000)
    }
}
