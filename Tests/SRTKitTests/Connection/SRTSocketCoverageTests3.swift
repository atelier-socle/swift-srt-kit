// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("SRTSocket Coverage Tests Part 4")
struct SRTSocketCoverageTests4 {

    private func makeConnectedSocket(
        socketID: UInt32 = 1,
        clock: MockSRTClock? = nil
    ) async -> SRTSocket {
        let socket: SRTSocket
        if let clock {
            socket = SRTSocket(
                role: .caller, socketID: socketID, clock: clock)
        } else {
            socket = SRTSocket(role: .caller, socketID: socketID)
        }
        await socket.transitionTo(.connecting)
        await socket.transitionTo(.handshaking)
        await socket.transitionTo(.connected)
        return socket
    }

    /// Encode a control packet to raw bytes using PacketCodec.
    private func encodeControl(
        controlType: ControlType,
        typeSpecificInfo: UInt32 = 0,
        cif: ControlInfoField
    ) -> [UInt8] {
        var buf = ByteBuffer()
        PacketCodec.encode(
            controlType: controlType,
            typeSpecificInfo: typeSpecificInfo,
            timestamp: 1000,
            destinationSocketID: 1,
            cif: cif,
            into: &buf)
        return Array(buf.readableBytesView)
    }

    private var localhost: SocketAddress {
        get throws {
            try SocketAddress(ipAddress: "127.0.0.1", port: 5000)
        }
    }

    // MARK: - ACK control packet

    @Test("handleIncomingPacket with ACK control packet does not crash")
    func handleACKControlPacket() async throws {
        let socket = await makeConnectedSocket()
        let ack = ACKPacket(
            acknowledgementNumber: SequenceNumber(5),
            rtt: 1000,
            rttVariance: 200,
            availableBufferSize: 8192,
            packetsReceivingRate: 1000,
            estimatedLinkCapacity: 5000,
            receivingRate: 125_000)
        let bytes = encodeControl(
            controlType: .ack, typeSpecificInfo: 1, cif: .ack(ack))
        try await socket.handleIncomingPacket(bytes, from: localhost)
        let state = await socket.state
        #expect(state == .connected)
    }

    @Test("handleIncomingPacket with light ACK does not crash")
    func handleLightACKControlPacket() async throws {
        let socket = await makeConnectedSocket()
        let lightACK = ACKPacket(acknowledgementNumber: SequenceNumber(10))
        let bytes = encodeControl(controlType: .ack, cif: .ack(lightACK))
        try await socket.handleIncomingPacket(bytes, from: localhost)
        let state = await socket.state
        #expect(state == .connected)
    }

    // MARK: - Unhandled control types (default: break)

    @Test("handleIncomingPacket with congestion control packet does not crash")
    func handleCongestionControlPacket() async throws {
        let socket = await makeConnectedSocket()
        let bytes = encodeControl(
            controlType: .congestion, cif: .raw([0x00, 0x00, 0x00, 0x01]))
        try await socket.handleIncomingPacket(bytes, from: localhost)
        let state = await socket.state
        #expect(state == .connected)
    }

    @Test("handleIncomingPacket with userDefined control packet does not crash")
    func handleUserDefinedControlPacket() async throws {
        let socket = await makeConnectedSocket()
        let bytes = encodeControl(
            controlType: .userDefined, cif: .raw([0xDE, 0xAD]))
        try await socket.handleIncomingPacket(bytes, from: localhost)
        let state = await socket.state
        #expect(state == .connected)
    }

    @Test("handleIncomingPacket with peerError control packet does not crash")
    func handlePeerErrorControlPacket() async throws {
        let socket = await makeConnectedSocket()
        let bytes = encodeControl(
            controlType: .peererror, cif: .peerError(42))
        try await socket.handleIncomingPacket(bytes, from: localhost)
        let state = await socket.state
        #expect(state == .connected)
    }

    // MARK: - Drop request control packet

    @Test("handleIncomingPacket with drop request control packet does not crash")
    func handleDropRequestControlPacket() async throws {
        let socket = await makeConnectedSocket()
        let drop = DropRequestPacket(
            messageNumber: 1,
            firstSequence: SequenceNumber(0),
            lastSequence: SequenceNumber(5))
        let bytes = encodeControl(
            controlType: .dropreq,
            typeSpecificInfo: 1,
            cif: .dropRequest(drop))
        try await socket.handleIncomingPacket(bytes, from: localhost)
        let state = await socket.state
        #expect(state == .connected)
    }

    // MARK: - Shutdown complete via tick

    @Test("tick exercises shutdown complete path after close")
    func tickShutdownCompletePath() async throws {
        let clock = MockSRTClock(startTime: 0)
        let socket = SRTSocket(
            role: .caller,
            socketID: 1,
            connectionConfiguration: .init(
                keepaliveInterval: 1_000_000,
                keepaliveTimeout: 5_000_000,
                shutdownTimeout: 100_000),
            clock: clock)
        await socket.transitionTo(.connecting)
        await socket.transitionTo(.handshaking)
        await socket.transitionTo(.connected)

        clock.set(to: 1000)
        await socket.close()
        let closingState = await socket.state
        #expect(closingState == .closing)

        // Advance past shutdown timeout
        clock.set(to: 200_000)
        try await socket.tick(currentTime: 200_000)
        let finalState = await socket.state
        #expect(finalState == .closed)
    }

    // MARK: - receive() returns data after handleIncomingPacket

    @Test("receive returns data queued by handleIncomingPacket")
    func receiveReturnsQueuedData() async throws {
        let socket = await makeConnectedSocket()
        let payload: [UInt8] = [0xCA, 0xFE, 0xBA, 0xBE]
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
            payload: payload)
        PacketCodec.encode(.data(dataPacket), into: &buf)
        let bytes = Array(buf.readableBytesView)
        try await socket.handleIncomingPacket(bytes, from: localhost)

        let received = await socket.receive()
        #expect(received == payload)
    }

    // MARK: - Multiple sequential sends

    @Test("multiple sequential sends update stats correctly")
    func multipleSequentialSends() async throws {
        let socket = await makeConnectedSocket()
        for i in 0..<12 {
            let payload = Array(repeating: UInt8(i & 0xFF), count: 100)
            _ = try await socket.send(payload)
        }
        let stats = await socket.statistics()
        #expect(stats.packetsSent >= 12)
        #expect(stats.bytesSent >= 1200)
    }

    // MARK: - ACKACK control packet

    @Test("handleIncomingPacket with ACKACK control packet does not crash")
    func handleACKACKControlPacket() async throws {
        let socket = await makeConnectedSocket()
        let bytes = encodeControl(
            controlType: .ackack, typeSpecificInfo: 1, cif: .ackack)
        try await socket.handleIncomingPacket(bytes, from: localhost)
        let state = await socket.state
        #expect(state == .connected)
    }

    // MARK: - NAK records packet loss stat

    @Test("handleIncomingPacket with NAK records packet lost stat")
    func handleNAKRecordsLoss() async throws {
        let socket = await makeConnectedSocket()
        let nak = NAKPacket(lossEntries: [.single(SequenceNumber(3))])
        let bytes = encodeControl(controlType: .nak, cif: .nak(nak))
        try await socket.handleIncomingPacket(bytes, from: localhost)
        let stats = await socket.statistics()
        #expect(stats.packetsSentLost >= 1)
    }
}
