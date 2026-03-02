// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import NIOPosix
import Testing

@testable import SRTKit

@Suite("UDPTransport Tests")
struct UDPTransportTests {
    // MARK: - State tests (no network I/O)

    @Test("Initial state is idle")
    func initialStateIsIdle() {
        let config = UDPTransport.Configuration(host: "127.0.0.1", port: 0)
        let transport = UDPTransport(configuration: config)
        // Actor isolation requires async access
        Task {
            let state = await transport.state
            #expect(state == .idle)
        }
    }

    // MARK: - Network I/O tests

    @Test(
        .tags(.network),
        .enabled(if: !isCI, "NIO UDP loopback may hang in CI"),
        .timeLimit(.minutes(1))
    )
    func bindTransitionsToBindState() async throws {
        let config = UDPTransport.Configuration(host: "127.0.0.1", port: 0)
        let transport = UDPTransport(configuration: config)
        _ = try await transport.bind()
        let state = await transport.state
        #expect(state == .bound)
        try await transport.close()
    }

    @Test(
        .tags(.network),
        .enabled(if: !isCI, "NIO UDP loopback may hang in CI"),
        .timeLimit(.minutes(1))
    )
    func bindReturnsValidLocalAddress() async throws {
        let config = UDPTransport.Configuration(host: "127.0.0.1", port: 0)
        let transport = UDPTransport(configuration: config)
        let addr = try await transport.bind()
        #expect(addr.port != nil)
        #expect(addr.port != 0)
        try await transport.close()
    }

    @Test(
        .tags(.network),
        .enabled(if: !isCI, "NIO UDP loopback may hang in CI"),
        .timeLimit(.minutes(1))
    )
    func bindOnEphemeralPort() async throws {
        let config = UDPTransport.Configuration(host: "127.0.0.1", port: 0)
        let transport = UDPTransport(configuration: config)
        let addr = try await transport.bind()
        let localAddr = await transport.localAddress
        #expect(localAddr != nil)
        #expect(addr.port ?? 0 > 0)
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
        try await transport.close()
        let state = await transport.state
        #expect(state == .closed)
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
        try await transport.close()
        try await transport.close()
        let state = await transport.state
        #expect(state == .closed)
    }

    @Test(
        .tags(.network),
        .enabled(if: !isCI, "NIO UDP loopback may hang in CI"),
        .timeLimit(.minutes(1))
    )
    func doubleBindThrowsError() async throws {
        let config = UDPTransport.Configuration(host: "127.0.0.1", port: 0)
        let transport = UDPTransport(configuration: config)
        _ = try await transport.bind()
        do {
            _ = try await transport.bind()
            #expect(Bool(false), "Expected error on double bind")
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
    func loopbackSendReceive() async throws {
        let configA = UDPTransport.Configuration(host: "127.0.0.1", port: 0)
        let transportA = UDPTransport(configuration: configA)
        let addrA = try await transportA.bind()

        let configB = UDPTransport.Configuration(host: "127.0.0.1", port: 0)
        let transportB = UDPTransport(configuration: configB)
        _ = try await transportB.bind()

        let incomingB = await transportB.incomingDatagrams

        // Send from A to B
        let allocator = ByteBufferAllocator()
        var buf = allocator.buffer(capacity: 5)
        buf.writeString("hello")
        try await transportA.send(buf, to: addrA)

        // Note: we're sending to A's own address for simplicity since
        // A and B are on different ports. Let's send to B instead.
        let addrBActual = await transportB.localAddress
        guard let addrB = addrBActual else {
            #expect(Bool(false), "B has no local address")
            try await transportA.close()
            try await transportB.close()
            return
        }

        var buf2 = allocator.buffer(capacity: 5)
        buf2.writeString("hello")
        try await transportA.send(buf2, to: addrB)

        var received: IncomingDatagram?
        for await datagram in incomingB {
            received = datagram
            break
        }

        #expect(received != nil)
        #expect(received?.data.readableBytes == 5)

        try await transportA.close()
        try await transportB.close()
    }

    @Test(
        .tags(.network),
        .enabled(if: !isCI, "NIO UDP loopback may hang in CI"),
        .timeLimit(.minutes(1))
    )
    func sendWithoutBindThrowsError() async throws {
        let config = UDPTransport.Configuration(host: "127.0.0.1", port: 0)
        let transport = UDPTransport(configuration: config)
        let addr = try SocketAddress.makeAddressResolvingHost("127.0.0.1", port: 9999)

        let allocator = ByteBufferAllocator()
        var buf = allocator.buffer(capacity: 4)
        buf.writeString("test")

        do {
            try await transport.send(buf, to: addr)
            #expect(Bool(false), "Expected error on send without bind")
        } catch {
            #expect(Bool(true))
        }
    }

    @Test(
        .tags(.network),
        .enabled(if: !isCI, "NIO UDP loopback may hang in CI"),
        .timeLimit(.minutes(1))
    )
    func externalEventLoopGroupUsed() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let config = UDPTransport.Configuration(
            host: "127.0.0.1", port: 0, eventLoopGroup: group
        )
        let transport = UDPTransport(configuration: config)
        _ = try await transport.bind()
        try await transport.close()
        // Group should still be alive (not owned by transport)
        try await group.shutdownGracefully()
    }

    @Test(
        .tags(.network),
        .enabled(if: !isCI, "NIO UDP loopback may hang in CI"),
        .timeLimit(.minutes(1))
    )
    func sendLargeDatagram() async throws {
        let configA = UDPTransport.Configuration(host: "127.0.0.1", port: 0)
        let transportA = UDPTransport(configuration: configA)
        _ = try await transportA.bind()

        let configB = UDPTransport.Configuration(host: "127.0.0.1", port: 0)
        let transportB = UDPTransport(configuration: configB)
        _ = try await transportB.bind()

        let incomingB = await transportB.incomingDatagrams
        let addrB = await transportB.localAddress

        guard let targetAddr = addrB else {
            try await transportA.close()
            try await transportB.close()
            return
        }

        // Send 1400 bytes (close to MTU)
        let allocator = ByteBufferAllocator()
        var buf = allocator.buffer(capacity: 1400)
        buf.writeBytes(Array(repeating: UInt8(0xAB), count: 1400))
        try await transportA.send(buf, to: targetAddr)

        var received: IncomingDatagram?
        for await datagram in incomingB {
            received = datagram
            break
        }

        #expect(received?.data.readableBytes == 1400)

        try await transportA.close()
        try await transportB.close()
    }
}
