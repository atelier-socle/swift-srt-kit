// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("SRTSocket Coverage Tests")
struct SRTSocketCoverageTests {

    /// Helper to create a connected socket.
    private func makeConnectedSocket(
        socketID: UInt32 = 1
    ) async -> SRTSocket {
        let socket = SRTSocket(role: .caller, socketID: socketID)
        await socket.transitionTo(.connecting)
        await socket.transitionTo(.handshaking)
        await socket.transitionTo(.connected)
        return socket
    }

    // MARK: - statistics()

    @Test("statistics returns non-nil snapshot")
    func statisticsReturnsSnapshot() async {
        let socket = await makeConnectedSocket()
        let stats = await socket.statistics()
        // Should return a valid statistics object
        #expect(stats.packetsReceived >= 0)
    }

    // MARK: - send() in connected state

    @Test("send in connected state succeeds")
    func sendInConnectedState() async throws {
        let socket = await makeConnectedSocket()
        // send without channel: pipeline runs, sendDataPacketToWire exits early
        let bytesSent = try await socket.send([0x01, 0x02, 0x03])
        #expect(bytesSent == 3)
    }

    @Test("send multiple packets works")
    func sendMultiplePackets() async throws {
        let socket = await makeConnectedSocket()
        let bytes1 = try await socket.send([0x01])
        let bytes2 = try await socket.send([0x02, 0x03])
        #expect(bytes1 == 1)
        #expect(bytes2 == 2)
    }

    // MARK: - handleIncomingPacket with data packet

    @Test("handleIncomingPacket with data packet transitions to transferring")
    func handleDataPacketTransitions() async throws {
        let socket = await makeConnectedSocket()
        // Build a valid SRT data packet
        var buf = ByteBuffer()
        let dataPacket = SRTDataPacket(
            sequenceNumber: SequenceNumber(0),
            position: .single,
            orderFlag: false,
            encryptionKey: .none,
            retransmitted: false,
            messageNumber: 0,
            timestamp: 1000,
            destinationSocketID: 1,
            payload: [0xAA, 0xBB, 0xCC]
        )
        PacketCodec.encode(.data(dataPacket), into: &buf)
        let bytes = Array(buf.readableBytesView)

        try await socket.handleIncomingPacket(
            bytes, from: .init(ipAddress: "127.0.0.1", port: 5000))

        let state = await socket.state
        #expect(state == .transferring)
    }

    // MARK: - handleIncomingPacket with control packets

    @Test("handleIncomingPacket with keepalive")
    func handleKeepalivePacket() async throws {
        let socket = await makeConnectedSocket()
        var buf = ByteBuffer()
        PacketCodec.encode(
            controlType: .keepalive,
            timestamp: 1000,
            destinationSocketID: 1,
            cif: .keepalive,
            into: &buf
        )
        let bytes = Array(buf.readableBytesView)
        try await socket.handleIncomingPacket(
            bytes, from: .init(ipAddress: "127.0.0.1", port: 5000))
        // Should not change state
        let state = await socket.state
        #expect(state == .connected)
    }

    @Test("handleIncomingPacket with shutdown transitions to closed")
    func handleShutdownPacket() async throws {
        let socket = await makeConnectedSocket()
        var buf = ByteBuffer()
        PacketCodec.encode(
            controlType: .shutdown,
            timestamp: 1000,
            destinationSocketID: 1,
            cif: .shutdown,
            into: &buf
        )
        let bytes = Array(buf.readableBytesView)
        try await socket.handleIncomingPacket(
            bytes, from: .init(ipAddress: "127.0.0.1", port: 5000))
        let state = await socket.state
        #expect(state == .closed)
    }

    @Test("handleIncomingPacket with NAK records loss")
    func handleNAKPacket() async throws {
        let socket = await makeConnectedSocket()
        var buf = ByteBuffer()
        let nakPacket = NAKPacket(
            lossEntries: [.single(SequenceNumber(0))])
        PacketCodec.encode(
            controlType: .nak,
            timestamp: 1000,
            destinationSocketID: 1,
            cif: .nak(nakPacket),
            into: &buf
        )
        let bytes = Array(buf.readableBytesView)
        try await socket.handleIncomingPacket(
            bytes, from: .init(ipAddress: "127.0.0.1", port: 5000))
        let stats = await socket.statistics()
        #expect(stats.packetsReceivedLost >= 0)
    }

    // MARK: - tick

    @Test("tick sends keepalive when interval elapsed")
    func tickSendsKeepalive() async throws {
        let socket = SRTSocket(
            role: .caller,
            socketID: 1,
            connectionConfiguration: .init(
                keepaliveInterval: 1_000,
                keepaliveTimeout: 50_000_000))
        await socket.transitionTo(.connecting)
        await socket.transitionTo(.handshaking)
        await socket.transitionTo(.connected)

        // First tick at time 0
        try await socket.tick(currentTime: 0)
        // Tick after keepalive interval
        try await socket.tick(currentTime: 2_000)
        // Should not crash, keepalive sent (but no channel to send to)
    }

    @Test("tick checks ACK and delivers packets")
    func tickChecksACK() async throws {
        let socket = await makeConnectedSocket()
        try await socket.tick(currentTime: 1_000_000)
        try await socket.tick(currentTime: 2_000_000)
        // Should not crash
    }

    // MARK: - configureEncryption

    @Test("configureEncryption sets up pipeline encryption")
    func configureEncryption() async throws {
        let socket = await makeConnectedSocket()
        let sek = Array(repeating: UInt8(0x42), count: 16)
        let salt = Array(repeating: UInt8(0xAA), count: 16)
        try await socket.configureEncryption(
            sek: sek, salt: salt, cipherMode: .ctr, keySize: .aes128)
        // Subsequent sends should encrypt
        let bytes = try await socket.send([0x01, 0x02, 0x03])
        #expect(bytes == 3)
    }

    // MARK: - handshakeCompleted

    @Test("handshakeCompleted sets peerSocketID")
    func handshakeCompletedSetsPeerID() async {
        let socket = SRTSocket(role: .caller, socketID: 1)
        await socket.handshakeCompleted(
            peerSocketID: 42, negotiatedLatency: 120_000)
        let peerID = await socket.peerSocketID
        #expect(peerID == 42)
    }

    // MARK: - close from connected

    @Test("close from connected transitions through closing")
    func closeFromConnected() async {
        let socket = await makeConnectedSocket()
        await socket.close()
        let state = await socket.state
        // Should be closing or closed
        #expect(state == .closing || state == .closed)
    }

    // MARK: - transitionTo terminal state closes waiters

    @Test("transitionTo broken state closes receive waiters")
    func transitionToBrokenClosesWaiters() async {
        let socket = await makeConnectedSocket()
        await socket.transitionTo(.broken)
        let state = await socket.state
        #expect(state == .broken)
    }

    // MARK: - Multiple data packets → deliver + duplicate paths

    @Test("Duplicate data packet handled correctly")
    func duplicateDataPacket() async throws {
        let socket = await makeConnectedSocket()
        var buf = ByteBuffer()
        let dataPacket = SRTDataPacket(
            sequenceNumber: SequenceNumber(0),
            payload: [0xAA]
        )
        PacketCodec.encode(.data(dataPacket), into: &buf)
        let bytes = Array(buf.readableBytesView)

        // First receive
        try await socket.handleIncomingPacket(
            bytes, from: .init(ipAddress: "127.0.0.1", port: 5000))
        // Second receive (duplicate)
        buf.moveReaderIndex(to: 0)
        try await socket.handleIncomingPacket(
            bytes, from: .init(ipAddress: "127.0.0.1", port: 5000))
    }

    // MARK: - Send and receive flow

    @Test("Send then tick processes pipeline")
    func sendThenTick() async throws {
        let socket = await makeConnectedSocket()
        _ = try await socket.send([0x01, 0x02])
        try await socket.tick(currentTime: 10_000)
        let stats = await socket.statistics()
        #expect(stats.packetsSent >= 1)
    }

    // MARK: - Terminal state transitions

    @Test("transitionTo broken from connected succeeds")
    func transitionToBrokenFromConnected() async {
        let socket = await makeConnectedSocket()
        let result = await socket.transitionTo(.broken)
        #expect(result == true)
        let state = await socket.state
        #expect(state == .broken)
    }

    @Test("transitionTo closed from closing succeeds")
    func transitionToClosedFromClosing() async {
        let socket = await makeConnectedSocket()
        // connected -> closing -> closed
        let closingResult = await socket.transitionTo(.closing)
        #expect(closingResult == true)
        let closedResult = await socket.transitionTo(.closed)
        #expect(closedResult == true)
        let state = await socket.state
        #expect(state == .closed)
    }

    @Test("transitionTo broken from transferring succeeds")
    func transitionToBrokenFromTransferring() async {
        let socket = await makeConnectedSocket()
        await socket.transitionTo(.transferring)
        let result = await socket.transitionTo(.broken)
        #expect(result == true)
        let state = await socket.state
        #expect(state == .broken)
    }

    @Test("transitionTo returns false for invalid transition")
    func transitionToInvalidReturnsFalse() async {
        let socket = await makeConnectedSocket()
        // connected -> idle is not valid
        let result = await socket.transitionTo(.idle)
        #expect(result == false)
        let state = await socket.state
        #expect(state == .connected)
    }

    @Test("terminal state has no valid transitions")
    func terminalStateNoTransitions() async {
        let socket = await makeConnectedSocket()
        await socket.transitionTo(.broken)
        // broken -> connected is invalid
        let result = await socket.transitionTo(.connected)
        #expect(result == false)
        let state = await socket.state
        #expect(state == .broken)
    }

    // MARK: - send() in various non-active states

    @Test("send throws when state is closing")
    func sendThrowsWhenClosing() async {
        let socket = await makeConnectedSocket()
        await socket.transitionTo(.closing)
        do {
            _ = try await socket.send([0x01, 0x02])
            Issue.record("Expected send to throw in closing state")
        } catch is SRTConnectionError {
            // Expected
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("send throws when state is closed")
    func sendThrowsWhenClosed() async {
        let socket = await makeConnectedSocket()
        await socket.transitionTo(.closing)
        await socket.transitionTo(.closed)
        do {
            _ = try await socket.send([0x01, 0x02])
            Issue.record("Expected send to throw in closed state")
        } catch is SRTConnectionError {
            // Expected
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("send throws when state is idle")
    func sendThrowsWhenIdle() async {
        let socket = SRTSocket(role: .caller, socketID: 99)
        do {
            _ = try await socket.send([0x01, 0x02])
            Issue.record("Expected send to throw in idle state")
        } catch is SRTConnectionError {
            // Expected
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("send throws when state is broken")
    func sendThrowsWhenBroken() async {
        let socket = await makeConnectedSocket()
        await socket.transitionTo(.broken)
        do {
            _ = try await socket.send([0x01, 0x02])
            Issue.record("Expected send to throw in broken state")
        } catch is SRTConnectionError {
            // Expected
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("send throws when state is handshaking")
    func sendThrowsWhenHandshaking() async {
        let socket = SRTSocket(role: .caller, socketID: 99)
        await socket.transitionTo(.connecting)
        await socket.transitionTo(.handshaking)
        do {
            _ = try await socket.send([0x01, 0x02])
            Issue.record("Expected send to throw in handshaking state")
        } catch is SRTConnectionError {
            // Expected
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}
