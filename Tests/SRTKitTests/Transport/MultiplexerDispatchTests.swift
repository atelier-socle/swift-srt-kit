// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("Multiplexer Dispatch Tests")
struct MultiplexerDispatchTests {
    private func makeAddress(port: Int) throws -> SocketAddress {
        try SocketAddress.makeAddressResolvingHost("127.0.0.1", port: port)
    }

    private func makePacket(
        destinationSocketID: UInt32,
        allocator: ByteBufferAllocator = ByteBufferAllocator()
    ) -> ByteBuffer {
        var buffer = allocator.buffer(capacity: 16)
        buffer.writeInteger(UInt32(0))
        buffer.writeInteger(UInt32(0))
        buffer.writeInteger(UInt32(0))
        buffer.writeInteger(destinationSocketID)
        return buffer
    }

    // MARK: - Dispatch by Socket ID

    @Test("Dispatch with known Socket ID delivers to correct connection")
    func dispatchKnownSocketID() async throws {
        let mux = Multiplexer()
        let addr = try makeAddress(port: 5000)
        let stream = await mux.register(socketID: 0xAAAA)
        let packet = makePacket(destinationSocketID: 0xAAAA)
        let datagram = IncomingDatagram(data: packet, remoteAddress: addr)

        await mux.dispatch(datagram)

        var received: IncomingDatagram?
        for await item in stream {
            received = item
            break
        }
        #expect(received != nil)
        #expect(received?.data.readableBytes == 16)
    }

    @Test("Dispatch with unknown Socket ID drops packet")
    func dispatchUnknownSocketID() async throws {
        let mux = Multiplexer()
        let addr = try makeAddress(port: 5000)
        _ = await mux.register(socketID: 0xAAAA)
        let packet = makePacket(destinationSocketID: 0xBBBB)
        let datagram = IncomingDatagram(data: packet, remoteAddress: addr)
        // Should not crash
        await mux.dispatch(datagram)
    }

    @Test("Multiple connections: each receives only its own packets")
    func multipleConnectionsCorrectRouting() async throws {
        let mux = Multiplexer()
        let addr = try makeAddress(port: 5000)
        let streamA = await mux.register(socketID: 0xAAAA)
        let streamB = await mux.register(socketID: 0xBBBB)

        let packetA = makePacket(destinationSocketID: 0xAAAA)
        let datagramA = IncomingDatagram(data: packetA, remoteAddress: addr)
        await mux.dispatch(datagramA)

        // Finish streamB to verify it got nothing
        await mux.unregister(socketID: 0xBBBB)

        var receivedA: IncomingDatagram?
        for await item in streamA {
            receivedA = item
            break
        }
        #expect(receivedA != nil)

        var receivedB: IncomingDatagram?
        for await item in streamB {
            receivedB = item
            break
        }
        #expect(receivedB == nil)
    }

    // MARK: - Dispatch by source address (pre-handshake)

    @Test("Socket ID 0 routes by source address")
    func dispatchBySourceAddress() async throws {
        let mux = Multiplexer()
        let peerAddr = try makeAddress(port: 6000)
        let stream = await mux.register(socketID: 0xAAAA, remoteAddress: peerAddr)

        let packet = makePacket(destinationSocketID: 0)
        let datagram = IncomingDatagram(data: packet, remoteAddress: peerAddr)
        await mux.dispatch(datagram)

        var received: IncomingDatagram?
        for await item in stream {
            received = item
            break
        }
        #expect(received != nil)
    }

    @Test("Socket ID 0 from unknown address is dropped")
    func dispatchSocketIDZeroUnknownAddress() async throws {
        let mux = Multiplexer()
        let knownAddr = try makeAddress(port: 6000)
        let unknownAddr = try makeAddress(port: 7000)
        _ = await mux.register(socketID: 0xAAAA, remoteAddress: knownAddr)

        let packet = makePacket(destinationSocketID: 0)
        let datagram = IncomingDatagram(data: packet, remoteAddress: unknownAddr)
        // Should not crash
        await mux.dispatch(datagram)
    }

    // MARK: - Edge cases

    @Test("Dispatch after unregister does not deliver")
    func dispatchAfterUnregister() async throws {
        let mux = Multiplexer()
        let addr = try makeAddress(port: 5000)
        let stream = await mux.register(socketID: 0xAAAA)
        await mux.unregister(socketID: 0xAAAA)

        let packet = makePacket(destinationSocketID: 0xAAAA)
        let datagram = IncomingDatagram(data: packet, remoteAddress: addr)
        await mux.dispatch(datagram)

        var received: IncomingDatagram?
        for await item in stream {
            received = item
            break
        }
        #expect(received == nil)
    }

    @Test("Large number of registrations dispatch correctly")
    func largeNumberOfRegistrations() async throws {
        let mux = Multiplexer()
        let addr = try makeAddress(port: 5000)

        var streams: [UInt32: AsyncStream<IncomingDatagram>] = [:]
        for i: UInt32 in 1...100 {
            streams[i] = await mux.register(socketID: i)
        }
        let count = await mux.connectionCount
        #expect(count == 100)

        // Dispatch to connection 50
        let packet = makePacket(destinationSocketID: 50)
        let datagram = IncomingDatagram(data: packet, remoteAddress: addr)
        await mux.dispatch(datagram)

        guard let stream50 = streams[50] else {
            #expect(Bool(false), "Stream 50 not found")
            return
        }

        var received: IncomingDatagram?
        for await item in stream50 {
            received = item
            break
        }
        #expect(received != nil)
    }

    // MARK: - Byte-level Socket ID extraction

    @Test("Big-endian Socket ID correctly extracted from bytes 12-15")
    func bigEndianSocketIDExtraction() async throws {
        let mux = Multiplexer()
        let addr = try makeAddress(port: 5000)
        let stream = await mux.register(socketID: 0x0102_0304)

        let allocator = ByteBufferAllocator()
        var buffer = allocator.buffer(capacity: 16)
        // 12 bytes of padding
        for _ in 0..<12 {
            buffer.writeInteger(UInt8(0))
        }
        // Write 0x01020304 in big-endian
        buffer.writeInteger(UInt8(0x01))
        buffer.writeInteger(UInt8(0x02))
        buffer.writeInteger(UInt8(0x03))
        buffer.writeInteger(UInt8(0x04))

        let datagram = IncomingDatagram(data: buffer, remoteAddress: addr)
        await mux.dispatch(datagram)

        var received: IncomingDatagram?
        for await item in stream {
            received = item
            break
        }
        #expect(received != nil)
    }

    @Test("Packet too short (< 16 bytes) uses Socket ID 0")
    func shortPacketUsesZero() async throws {
        let mux = Multiplexer()
        let addr = try makeAddress(port: 5000)
        let peerAddr = try makeAddress(port: 6000)
        let stream = await mux.register(socketID: 0xAAAA, remoteAddress: peerAddr)

        let allocator = ByteBufferAllocator()
        var buffer = allocator.buffer(capacity: 4)
        buffer.writeInteger(UInt32(0))

        let datagram = IncomingDatagram(data: buffer, remoteAddress: peerAddr)
        await mux.dispatch(datagram)

        var received: IncomingDatagram?
        for await item in stream {
            received = item
            break
        }
        #expect(received != nil)
    }
}
