// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("Multiplexer Tests")
struct MultiplexerTests {
    private func makeAddress(port: Int) throws -> SocketAddress {
        try SocketAddress.makeAddressResolvingHost("127.0.0.1", port: port)
    }

    /// Build a minimal SRT-like packet with a destination socket ID at bytes 12-15.
    private func makePacket(
        destinationSocketID: UInt32,
        allocator: ByteBufferAllocator = ByteBufferAllocator()
    ) -> ByteBuffer {
        var buffer = allocator.buffer(capacity: 16)
        // 12 bytes of header padding (timestamp, etc.)
        buffer.writeInteger(UInt32(0))
        buffer.writeInteger(UInt32(0))
        buffer.writeInteger(UInt32(0))
        // Destination Socket ID at bytes 12-15
        buffer.writeInteger(destinationSocketID)
        return buffer
    }

    // MARK: - Registration

    @Test("Register increases connectionCount")
    func registerIncreasesCount() async {
        let mux = Multiplexer()
        _ = await mux.register(socketID: 100)
        let count = await mux.connectionCount
        #expect(count == 1)
    }

    @Test("Unregister decreases connectionCount")
    func unregisterDecreasesCount() async {
        let mux = Multiplexer()
        _ = await mux.register(socketID: 100)
        await mux.unregister(socketID: 100)
        let count = await mux.connectionCount
        #expect(count == 0)
    }

    @Test("Register multiple connections")
    func registerMultiple() async {
        let mux = Multiplexer()
        _ = await mux.register(socketID: 100)
        _ = await mux.register(socketID: 200)
        _ = await mux.register(socketID: 300)
        let count = await mux.connectionCount
        #expect(count == 3)
    }

    @Test("registeredSocketIDs returns correct set")
    func registeredSocketIDs() async {
        let mux = Multiplexer()
        _ = await mux.register(socketID: 10)
        _ = await mux.register(socketID: 20)
        let ids = await mux.registeredSocketIDs
        #expect(ids == [10, 20])
    }

    @Test("Unregister non-existent ID is idempotent")
    func unregisterNonExistent() async {
        let mux = Multiplexer()
        await mux.unregister(socketID: 999)
        let count = await mux.connectionCount
        #expect(count == 0)
    }

    @Test("Register same socketID twice replaces previous")
    func registerSameIDTwice() async {
        let mux = Multiplexer()
        _ = await mux.register(socketID: 100)
        _ = await mux.register(socketID: 100)
        let count = await mux.connectionCount
        #expect(count == 1)
    }
}
