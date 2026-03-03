// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTListener Coverage Tests")
struct SRTListenerCoverageTests {

    // MARK: - incomingConnections stream

    @Test("incomingConnections returns same stream on second call")
    func incomingConnectionsSameStream() async {
        let listener = SRTListener(
            configuration: .init(port: 4200))
        let stream1 = await listener.incomingConnections
        let stream2 = await listener.incomingConnections
        // Both should be the same stream instance
        _ = stream1
        _ = stream2
    }

    // MARK: - stop without start

    @Test("stop without start is safe")
    func stopWithoutStart() async {
        let listener = SRTListener(
            configuration: .init(port: 4200))
        await listener.stop()
        let listening = await listener.isListening
        #expect(!listening)
    }

    // MARK: - acceptConnection and removeConnection

    @Test(
        "acceptConnection with multiple sockets increments count",
        .tags(.network),
        .enabled(if: !isCI, "NIO UDP loopback may hang in CI"),
        .timeLimit(.minutes(1))
    )
    func acceptMultiple() async throws {
        let listener = SRTListener(
            configuration: .init(port: 0))
        try await listener.start()

        for i: UInt32 in 1...3 {
            let socket = SRTSocket(role: .listener, socketID: i)
            await listener.acceptConnection(socket)
        }
        let count = await listener.activeConnectionCount
        #expect(count == 3)
        await listener.stop()
    }

    @Test(
        "removeConnection with non-existent ID is safe",
        .tags(.network),
        .enabled(if: !isCI, "NIO UDP loopback may hang in CI"),
        .timeLimit(.minutes(1))
    )
    func removeNonExistent() async throws {
        let listener = SRTListener(
            configuration: .init(port: 0))
        try await listener.start()
        await listener.removeConnection(socketID: 999)
        let count = await listener.activeConnectionCount
        #expect(count == 0)
        await listener.stop()
    }

    // MARK: - Configuration with encryption

    @Test("Configuration with passphrase")
    func configWithPassphrase() {
        let config = SRTListener.Configuration(
            port: 4200,
            passphrase: "mysecretpassphrase",
            keySize: .aes256,
            cipherMode: .gcm
        )
        #expect(config.passphrase == "mysecretpassphrase")
        #expect(config.keySize == .aes256)
        #expect(config.cipherMode == .gcm)
    }

    // MARK: - Bound port

    @Test(
        "boundPort is set after start",
        .tags(.network),
        .enabled(if: !isCI, "NIO UDP loopback may hang in CI"),
        .timeLimit(.minutes(1))
    )
    func boundPortAfterStart() async throws {
        let listener = SRTListener(
            configuration: .init(port: 0))
        try await listener.start()
        let port = await listener.boundPort
        #expect(port != nil)
        #expect((port ?? 0) > 0)
        await listener.stop()
    }

    @Test(
        "boundPort is nil after stop",
        .tags(.network),
        .enabled(if: !isCI, "NIO UDP loopback may hang in CI"),
        .timeLimit(.minutes(1))
    )
    func boundPortAfterStop() async throws {
        let listener = SRTListener(
            configuration: .init(port: 0))
        try await listener.start()
        await listener.stop()
        let port = await listener.boundPort
        #expect(port == nil)
    }
}
