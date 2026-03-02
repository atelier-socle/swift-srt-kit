// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import NIOPosix
import Testing

@testable import SRTKit

@Suite("UDPChannel Tests")
struct UDPChannelTests {
    // MARK: - State tests (no network I/O)

    @Test("Initial state is idle")
    func initialStateIsIdle() async {
        let config = UDPTransport.Configuration(host: "127.0.0.1", port: 0)
        let transport = UDPTransport(configuration: config)
        let mux = Multiplexer()
        let channel = UDPChannel(
            socketID: 0x1234, transport: transport, multiplexer: mux
        )
        let state = await channel.state
        #expect(state == .idle)
    }

    @Test("socketID is set correctly")
    func socketIDSet() async {
        let config = UDPTransport.Configuration(host: "127.0.0.1", port: 0)
        let transport = UDPTransport(configuration: config)
        let mux = Multiplexer()
        let channel = UDPChannel(
            socketID: 0xABCD, transport: transport, multiplexer: mux
        )
        let sid = await channel.socketID
        #expect(sid == 0xABCD)
    }

    // MARK: - Network I/O tests

    @Test(
        .tags(.network),
        .enabled(if: !isCI, "NIO UDP loopback may hang in CI"),
        .timeLimit(.minutes(1))
    )
    func openTransitionsToOpen() async throws {
        let config = UDPTransport.Configuration(host: "127.0.0.1", port: 0)
        let transport = UDPTransport(configuration: config)
        _ = try await transport.bind()
        let mux = Multiplexer()
        let channel = UDPChannel(
            socketID: 0x1234, transport: transport, multiplexer: mux
        )
        _ = await channel.open()
        let state = await channel.state
        #expect(state == .open)
        let count = await mux.connectionCount
        #expect(count == 1)
        await channel.close()
        try await transport.close()
    }

    @Test(
        .tags(.network),
        .enabled(if: !isCI, "NIO UDP loopback may hang in CI"),
        .timeLimit(.minutes(1))
    )
    func closeTransitionsToClosed() async throws {
        let config = UDPTransport.Configuration(host: "127.0.0.1", port: 0)
        let transport = UDPTransport(configuration: config)
        _ = try await transport.bind()
        let mux = Multiplexer()
        let channel = UDPChannel(
            socketID: 0x1234, transport: transport, multiplexer: mux
        )
        _ = await channel.open()
        await channel.close()
        let state = await channel.state
        #expect(state == .closed)
        let count = await mux.connectionCount
        #expect(count == 0)
        try await transport.close()
    }

    @Test(
        .tags(.network),
        .enabled(if: !isCI, "NIO UDP loopback may hang in CI"),
        .timeLimit(.minutes(1))
    )
    func closeIdempotent() async throws {
        let config = UDPTransport.Configuration(host: "127.0.0.1", port: 0)
        let transport = UDPTransport(configuration: config)
        _ = try await transport.bind()
        let mux = Multiplexer()
        let channel = UDPChannel(
            socketID: 0x1234, transport: transport, multiplexer: mux
        )
        _ = await channel.open()
        await channel.close()
        await channel.close()
        let state = await channel.state
        #expect(state == .closed)
        try await transport.close()
    }

    @Test(
        .tags(.network),
        .enabled(if: !isCI, "NIO UDP loopback may hang in CI"),
        .timeLimit(.minutes(1))
    )
    func setRemoteAddressUpdates() async throws {
        let config = UDPTransport.Configuration(host: "127.0.0.1", port: 0)
        let transport = UDPTransport(configuration: config)
        _ = try await transport.bind()
        let mux = Multiplexer()
        let channel = UDPChannel(
            socketID: 0x1234, transport: transport, multiplexer: mux
        )
        let addr = try SocketAddress.makeAddressResolvingHost("127.0.0.1", port: 9999)
        await channel.setRemoteAddress(addr)
        let remote = await channel.remoteAddress
        #expect(remote != nil)
        #expect(remote?.port == 9999)
        try await transport.close()
    }

    @Test(
        .tags(.network),
        .enabled(if: !isCI, "NIO UDP loopback may hang in CI"),
        .timeLimit(.minutes(1))
    )
    func sendAfterCloseThrowsError() async throws {
        let config = UDPTransport.Configuration(host: "127.0.0.1", port: 0)
        let transport = UDPTransport(configuration: config)
        _ = try await transport.bind()
        let mux = Multiplexer()
        let addr = try SocketAddress.makeAddressResolvingHost("127.0.0.1", port: 9999)
        let channel = UDPChannel(
            socketID: 0x1234, transport: transport, multiplexer: mux,
            remoteAddress: addr
        )
        _ = await channel.open()
        await channel.close()

        let allocator = ByteBufferAllocator()
        var buf = allocator.buffer(capacity: 4)
        buf.writeString("test")

        do {
            try await channel.send(buf)
            #expect(Bool(false), "Expected error on send after close")
        } catch {
            #expect(Bool(true))
        }
        try await transport.close()
    }

    @Test(
        .tags(.network),
        .enabled(if: !isCI, "NIO UDP loopback may hang in CI"),
        .timeLimit(.minutes(1))
    )
    func sendWithoutRemoteAddressThrowsError() async throws {
        let config = UDPTransport.Configuration(host: "127.0.0.1", port: 0)
        let transport = UDPTransport(configuration: config)
        _ = try await transport.bind()
        let mux = Multiplexer()
        let channel = UDPChannel(
            socketID: 0x1234, transport: transport, multiplexer: mux
        )
        _ = await channel.open()

        let allocator = ByteBufferAllocator()
        var buf = allocator.buffer(capacity: 4)
        buf.writeString("test")

        do {
            try await channel.send(buf)
            #expect(Bool(false), "Expected error without remote address")
        } catch {
            #expect(Bool(true))
        }

        await channel.close()
        try await transport.close()
    }

    @Test(
        .tags(.network),
        .enabled(if: !isCI, "NIO UDP loopback may hang in CI"),
        .timeLimit(.minutes(1))
    )
    func twoChannelsOnSameTransport() async throws {
        let config = UDPTransport.Configuration(host: "127.0.0.1", port: 0)
        let transport = UDPTransport(configuration: config)
        _ = try await transport.bind()
        let mux = Multiplexer()
        let channelA = UDPChannel(
            socketID: 0xAAAA, transport: transport, multiplexer: mux
        )
        let channelB = UDPChannel(
            socketID: 0xBBBB, transport: transport, multiplexer: mux
        )
        _ = await channelA.open()
        _ = await channelB.open()

        let count = await mux.connectionCount
        #expect(count == 2)

        let ids = await mux.registeredSocketIDs
        #expect(ids.contains(0xAAAA))
        #expect(ids.contains(0xBBBB))

        await channelA.close()
        await channelB.close()
        try await transport.close()
    }
}
