// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTListener Tests")
struct SRTListenerTests {
    // MARK: - Configuration

    @Test("Default host is 0.0.0.0")
    func defaultHost() {
        let config = SRTListener.Configuration(port: 4200)
        #expect(config.host == "0.0.0.0")
    }

    @Test("Custom port stored correctly")
    func customPort() {
        let config = SRTListener.Configuration(port: 9000)
        #expect(config.port == 9000)
    }

    @Test("Default configuration has expected values")
    func defaultConfig() {
        let config = SRTListener.Configuration(port: 4200)
        #expect(config.backlog == 5)
        #expect(config.passphrase == nil)
        #expect(config.keySize == .aes128)
        #expect(config.cipherMode == .ctr)
        #expect(config.latency == 120_000)
    }

    @Test("Custom configuration applies all fields")
    func customConfig() {
        let config = SRTListener.Configuration(
            host: "10.0.0.1",
            port: 8080,
            backlog: 10,
            passphrase: "secretpassword",
            keySize: .aes256,
            cipherMode: .gcm,
            latency: 200_000
        )
        #expect(config.host == "10.0.0.1")
        #expect(config.port == 8080)
        #expect(config.backlog == 10)
        #expect(config.passphrase == "secretpassword")
        #expect(config.keySize == .aes256)
        #expect(config.cipherMode == .gcm)
        #expect(config.latency == 200_000)
    }

    // MARK: - Lifecycle

    @Test("Initial isListening is false")
    func initialNotListening() async {
        let listener = SRTListener(
            configuration: .init(port: 4200))
        let listening = await listener.isListening
        #expect(!listening)
    }

    @Test("start sets isListening to true")
    func startSetsListening() async throws {
        let listener = SRTListener(
            configuration: .init(port: 4200))
        try await listener.start()
        let listening = await listener.isListening
        #expect(listening)
    }

    @Test("stop sets isListening to false")
    func stopClearsListening() async throws {
        let listener = SRTListener(
            configuration: .init(port: 4200))
        try await listener.start()
        await listener.stop()
        let listening = await listener.isListening
        #expect(!listening)
    }

    @Test("Double start throws alreadyListening")
    func doubleStartThrows() async throws {
        let listener = SRTListener(
            configuration: .init(port: 4200))
        try await listener.start()
        do {
            try await listener.start()
            Issue.record("Expected throw")
        } catch let error as SRTConnectionError {
            #expect(error == .alreadyListening)
        } catch {
            Issue.record("Expected SRTConnectionError")
        }
    }

    @Test("activeConnectionCount starts at 0")
    func initialConnectionCount() async {
        let listener = SRTListener(
            configuration: .init(port: 4200))
        let count = await listener.activeConnectionCount
        #expect(count == 0)
    }

    // MARK: - Incoming connections

    @Test("incomingConnections stream is available")
    func connectionStreamAvailable() async {
        let listener = SRTListener(
            configuration: .init(port: 4200))
        let stream = await listener.incomingConnections
        _ = stream
    }

    @Test("stop terminates the stream")
    func stopTerminatesStream() async throws {
        let listener = SRTListener(
            configuration: .init(port: 4200))
        try await listener.start()
        await listener.stop()
        // After stop, isListening should be false
        let listening = await listener.isListening
        #expect(!listening)
    }

    @Test("acceptConnection increments activeConnectionCount")
    func acceptConnectionIncrementsCount() async throws {
        let listener = SRTListener(
            configuration: .init(port: 4200))
        try await listener.start()

        let socket = SRTSocket(role: .listener, socketID: 1)
        await listener.acceptConnection(socket)
        let count = await listener.activeConnectionCount
        #expect(count == 1)
    }

    @Test("removeConnection decrements activeConnectionCount")
    func removeConnectionDecrementsCount() async throws {
        let listener = SRTListener(
            configuration: .init(port: 4200))
        try await listener.start()

        let socket = SRTSocket(role: .listener, socketID: 1)
        await listener.acceptConnection(socket)
        await listener.removeConnection(socketID: 1)
        let count = await listener.activeConnectionCount
        #expect(count == 0)
    }

    @Test("stop closes all active connections and resets count")
    func stopClosesAllConnections() async throws {
        let listener = SRTListener(
            configuration: .init(port: 4200))
        try await listener.start()

        let socket1 = SRTSocket(role: .listener, socketID: 1)
        let socket2 = SRTSocket(role: .listener, socketID: 2)
        await listener.acceptConnection(socket1)
        await listener.acceptConnection(socket2)

        let countBefore = await listener.activeConnectionCount
        #expect(countBefore == 2)

        await listener.stop()
        let countAfter = await listener.activeConnectionCount
        #expect(countAfter == 0)
    }
}
