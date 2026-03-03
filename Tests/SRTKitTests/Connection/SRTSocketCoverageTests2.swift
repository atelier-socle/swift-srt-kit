// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("SRTSocket Coverage Tests Part 2")
struct SRTSocketCoverageTests2 {

    private func makeConnectedSocket(
        socketID: UInt32 = 1
    ) async -> SRTSocket {
        let socket = SRTSocket(role: .caller, socketID: socketID)
        await socket.transitionTo(.connecting)
        await socket.transitionTo(.handshaking)
        await socket.transitionTo(.connected)
        return socket
    }

    // MARK: - handleIncomingPacket with malformed data

    @Test("handleIncomingPacket with empty data throws")
    func handleEmptyPacketThrows() async throws {
        let socket = await makeConnectedSocket()
        do {
            try await socket.handleIncomingPacket(
                [], from: .init(ipAddress: "127.0.0.1", port: 5000))
            Issue.record("Expected handleIncomingPacket to throw for empty data")
        } catch is SRTError {
            // Expected — buffer too small
        }
    }

    @Test("handleIncomingPacket with 1 byte throws")
    func handleOneBytePacketThrows() async throws {
        let socket = await makeConnectedSocket()
        do {
            try await socket.handleIncomingPacket(
                [0xFF], from: .init(ipAddress: "127.0.0.1", port: 5000))
            Issue.record("Expected handleIncomingPacket to throw for 1 byte")
        } catch is SRTError {
            // Expected — buffer too small
        }
    }

    @Test("handleIncomingPacket with 8 bytes throws")
    func handleEightBytePacketThrows() async throws {
        let socket = await makeConnectedSocket()
        do {
            try await socket.handleIncomingPacket(
                [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07],
                from: .init(ipAddress: "127.0.0.1", port: 5000))
            Issue.record("Expected handleIncomingPacket to throw for 8 bytes")
        } catch is SRTError {
            // Expected — buffer too small
        }
    }

    @Test("handleIncomingPacket with 15 bytes throws")
    func handleFifteenBytePacketThrows() async throws {
        let socket = await makeConnectedSocket()
        let data = Array(repeating: UInt8(0xAB), count: 15)
        do {
            try await socket.handleIncomingPacket(
                data, from: .init(ipAddress: "127.0.0.1", port: 5000))
            Issue.record("Expected handleIncomingPacket to throw for 15 bytes")
        } catch is SRTError {
            // Expected — buffer too small
        }
    }

    // MARK: - tick() with ACK generation

    @Test("tick at multiple time intervals does not crash")
    func tickMultipleIntervals() async throws {
        let socket = await makeConnectedSocket()
        for t in stride(from: UInt64(0), through: 100_000, by: 10_000) {
            try await socket.tick(currentTime: t)
        }
    }

    @Test("tick after receiving data exercises ACK path")
    func tickAfterReceivingDataACK() async throws {
        let socket = await makeConnectedSocket()
        for seq in UInt32(0)..<5 {
            var buf = ByteBuffer()
            let dataPacket = SRTDataPacket(
                sequenceNumber: SequenceNumber(seq),
                position: .single,
                orderFlag: false,
                encryptionKey: .none,
                retransmitted: false,
                messageNumber: 0,
                timestamp: 1000 + seq,
                destinationSocketID: 1,
                payload: [UInt8(seq)]
            )
            PacketCodec.encode(.data(dataPacket), into: &buf)
            let bytes = Array(buf.readableBytesView)
            try await socket.handleIncomingPacket(
                bytes, from: .init(ipAddress: "127.0.0.1", port: 5000))
        }
        try await socket.tick(currentTime: 10_000)
        try await socket.tick(currentTime: 20_000)
        try await socket.tick(currentTime: 50_000)
    }

    @Test("tick with large time gap exercises keepalive timeout path")
    func tickLargeTimeGap() async throws {
        let socket = SRTSocket(
            role: .caller,
            socketID: 1,
            connectionConfiguration: .init(
                keepaliveInterval: 1_000,
                keepaliveTimeout: 10_000))
        await socket.transitionTo(.connecting)
        await socket.transitionTo(.handshaking)
        await socket.transitionTo(.connected)

        var buf = ByteBuffer()
        let dataPacket = SRTDataPacket(
            sequenceNumber: SequenceNumber(0),
            position: .single,
            orderFlag: false,
            encryptionKey: .none,
            retransmitted: false,
            messageNumber: 0,
            timestamp: 100,
            destinationSocketID: 1,
            payload: [0x01]
        )
        PacketCodec.encode(.data(dataPacket), into: &buf)
        let bytes = Array(buf.readableBytesView)
        try await socket.handleIncomingPacket(
            bytes, from: .init(ipAddress: "127.0.0.1", port: 5000))

        try await socket.tick(currentTime: 50_000_000)
        let state = await socket.state
        #expect(state == .broken)
    }

    // MARK: - close() idempotency

    @Test("close when already closed is idempotent")
    func closeWhenAlreadyClosed() async {
        let socket = await makeConnectedSocket()
        await socket.close()
        let stateAfterFirst = await socket.state
        await socket.close()
        let stateAfterSecond = await socket.state
        #expect(stateAfterFirst == .closing || stateAfterFirst == .closed)
        #expect(stateAfterSecond == .closing || stateAfterSecond == .closed)
    }

    @Test("close when broken is idempotent")
    func closeWhenBroken() async {
        let socket = await makeConnectedSocket()
        await socket.transitionTo(.broken)
        await socket.close()
        let state = await socket.state
        #expect(state == .broken)
    }

    @Test("close twice from connected does not crash")
    func closeTwiceFromConnected() async {
        let socket = await makeConnectedSocket()
        await socket.close()
        await socket.close()
        let state = await socket.state
        #expect(state.isTerminal || state == .closing)
    }
}

@Suite("SRTSocket Coverage Tests Part 3")
struct SRTSocketCoverageTests3 {

    private func makeConnectedSocket(
        socketID: UInt32 = 1
    ) async -> SRTSocket {
        let socket = SRTSocket(role: .caller, socketID: socketID)
        await socket.transitionTo(.connecting)
        await socket.transitionTo(.handshaking)
        await socket.transitionTo(.connected)
        return socket
    }

    // MARK: - configureEncryption with different cipher modes

    @Test("configureEncryption with GCM mode succeeds")
    func configureEncryptionGCM() async throws {
        let socket = await makeConnectedSocket()
        let sek = Array(repeating: UInt8(0x42), count: 16)
        let salt = Array(repeating: UInt8(0xAA), count: 16)
        try await socket.configureEncryption(
            sek: sek, salt: salt, cipherMode: .gcm, keySize: .aes128)
        let bytes = try await socket.send([0x01, 0x02, 0x03])
        #expect(bytes == 3)
    }

    @Test("configureEncryption with AES-256 CTR succeeds")
    func configureEncryptionAES256CTR() async throws {
        let socket = await makeConnectedSocket()
        let sek = Array(repeating: UInt8(0x55), count: 32)
        let salt = Array(repeating: UInt8(0xBB), count: 16)
        try await socket.configureEncryption(
            sek: sek, salt: salt, cipherMode: .ctr, keySize: .aes256)
        let bytes = try await socket.send([0xDE, 0xAD])
        #expect(bytes == 2)
    }

    @Test("configureEncryption with AES-192 GCM succeeds")
    func configureEncryptionAES192GCM() async throws {
        let socket = await makeConnectedSocket()
        let sek = Array(repeating: UInt8(0x77), count: 24)
        let salt = Array(repeating: UInt8(0xCC), count: 16)
        try await socket.configureEncryption(
            sek: sek, salt: salt, cipherMode: .gcm, keySize: .aes192)
        let bytes = try await socket.send([0x01])
        #expect(bytes == 1)
    }

    // MARK: - tick returns ACK actions after enough data

    @Test("tick after many data packets exercises full ACK path")
    func tickAfterManyDataPackets() async throws {
        let socket = await makeConnectedSocket()
        for seq in UInt32(0)..<20 {
            var buf = ByteBuffer()
            let dataPacket = SRTDataPacket(
                sequenceNumber: SequenceNumber(seq),
                position: .single,
                orderFlag: false,
                encryptionKey: .none,
                retransmitted: false,
                messageNumber: 0,
                timestamp: 1000 * (seq + 1),
                destinationSocketID: 1,
                payload: Array(repeating: UInt8(seq & 0xFF), count: 100)
            )
            PacketCodec.encode(.data(dataPacket), into: &buf)
            let bytes = Array(buf.readableBytesView)
            try await socket.handleIncomingPacket(
                bytes, from: .init(ipAddress: "127.0.0.1", port: 5000))
        }
        try await socket.tick(currentTime: 10_000)
        try await socket.tick(currentTime: 20_000)
        try await socket.tick(currentTime: 100_000)
        try await socket.tick(currentTime: 200_000)
        let stats = await socket.statistics()
        #expect(stats.packetsReceived == 20)
    }

    @Test("tick after interleaved send and receive")
    func tickAfterInterleavedSendReceive() async throws {
        let socket = await makeConnectedSocket()
        _ = try await socket.send([0x01, 0x02, 0x03])
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
            payload: [0xAA, 0xBB]
        )
        PacketCodec.encode(.data(dataPacket), into: &buf)
        let bytes = Array(buf.readableBytesView)
        try await socket.handleIncomingPacket(
            bytes, from: .init(ipAddress: "127.0.0.1", port: 5000))
        _ = try await socket.send([0x04, 0x05])
        try await socket.tick(currentTime: 10_000)
        try await socket.tick(currentTime: 50_000)
        let stats = await socket.statistics()
        #expect(stats.packetsSent >= 2)
        #expect(stats.packetsReceived >= 1)
    }

    // MARK: - statistics after activity

    @Test("statistics returns non-zero packetsSent after send")
    func statisticsAfterSend() async throws {
        let socket = await makeConnectedSocket()
        _ = try await socket.send([0x01, 0x02, 0x03])
        _ = try await socket.send([0x04, 0x05])
        let stats = await socket.statistics()
        #expect(stats.packetsSent >= 2)
        #expect(stats.bytesSent >= 5)
    }

    @Test("statistics returns non-zero packetsReceived after receive")
    func statisticsAfterReceive() async throws {
        let socket = await makeConnectedSocket()
        for seq in UInt32(0)..<3 {
            var buf = ByteBuffer()
            let dataPacket = SRTDataPacket(
                sequenceNumber: SequenceNumber(seq),
                position: .single,
                orderFlag: false,
                encryptionKey: .none,
                retransmitted: false,
                messageNumber: 0,
                timestamp: 1000 + seq,
                destinationSocketID: 1,
                payload: [UInt8(seq), 0xFF]
            )
            PacketCodec.encode(.data(dataPacket), into: &buf)
            let bytes = Array(buf.readableBytesView)
            try await socket.handleIncomingPacket(
                bytes, from: .init(ipAddress: "127.0.0.1", port: 5000))
        }
        let stats = await socket.statistics()
        #expect(stats.packetsReceived == 3)
        #expect(stats.bytesReceived >= 6)
    }

    @Test("statistics tracks duplicate packets")
    func statisticsTracksDuplicates() async throws {
        let socket = await makeConnectedSocket()
        var buf2 = ByteBuffer()
        let outOfOrder = SRTDataPacket(
            sequenceNumber: SequenceNumber(2),
            position: .single,
            orderFlag: false,
            encryptionKey: .none,
            retransmitted: false,
            messageNumber: 0,
            timestamp: 1000,
            destinationSocketID: 1,
            payload: [0xBB]
        )
        PacketCodec.encode(.data(outOfOrder), into: &buf2)
        let ooBytes = Array(buf2.readableBytesView)
        try await socket.handleIncomingPacket(
            ooBytes, from: .init(ipAddress: "127.0.0.1", port: 5000))
        try await socket.handleIncomingPacket(
            ooBytes, from: .init(ipAddress: "127.0.0.1", port: 5000))
        let stats = await socket.statistics()
        #expect(stats.packetsReceived >= 2)
        #expect(stats.packetsDuplicate >= 1)
    }

    @Test("statistics tracks send buffer via tick")
    func statisticsTracksSendBuffer() async throws {
        let socket = await makeConnectedSocket()
        _ = try await socket.send(Array(repeating: 0x42, count: 500))
        _ = try await socket.send(Array(repeating: 0x43, count: 500))
        try await socket.tick(currentTime: 10_000)
        let stats = await socket.statistics()
        #expect(stats.packetsSent >= 2)
    }

    // MARK: - Misc coverage

    @Test("handshakeCompleted with zero latency")
    func handshakeCompletedZeroLatency() async {
        let socket = SRTSocket(role: .listener, socketID: 10)
        await socket.handshakeCompleted(
            peerSocketID: 99, negotiatedLatency: 0)
        let peerID = await socket.peerSocketID
        #expect(peerID == 99)
    }

    @Test("handshakeCompleted with large latency value")
    func handshakeCompletedLargeLatency() async {
        let socket = SRTSocket(role: .rendezvous, socketID: 5)
        await socket.handshakeCompleted(
            peerSocketID: 1000, negotiatedLatency: 5_000_000)
        let peerID = await socket.peerSocketID
        #expect(peerID == 1000)
    }

    @Test("socket with listener role can be created and connected")
    func listenerRoleSocket() async throws {
        let socket = SRTSocket(role: .listener, socketID: 42)
        await socket.transitionTo(.connecting)
        await socket.transitionTo(.handshaking)
        await socket.transitionTo(.connected)
        let state = await socket.state
        #expect(state == .connected)
        let bytes = try await socket.send([0x01])
        #expect(bytes == 1)
    }

    @Test("socket with rendezvous role can be created and connected")
    func rendezvousRoleSocket() async throws {
        let socket = SRTSocket(role: .rendezvous, socketID: 77)
        await socket.transitionTo(.connecting)
        await socket.transitionTo(.handshaking)
        await socket.transitionTo(.connected)
        let state = await socket.state
        #expect(state == .connected)
        let bytes = try await socket.send([0x01])
        #expect(bytes == 1)
    }

    @Test("receive returns nil when idle")
    func receiveReturnsNilWhenIdle() async {
        let socket = SRTSocket(role: .caller, socketID: 1)
        let data = await socket.receive()
        #expect(data == nil)
    }

    @Test("receive returns nil when broken")
    func receiveReturnsNilWhenBroken() async {
        let socket = await makeConnectedSocket()
        await socket.transitionTo(.broken)
        let data = await socket.receive()
        #expect(data == nil)
    }
}
