// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTCaller Tests")
struct SRTCallerTests {
    // MARK: - Configuration

    @Test("Default configuration has expected values")
    func defaultConfig() {
        let config = SRTCaller.Configuration(host: "127.0.0.1", port: 4200)
        #expect(config.host == "127.0.0.1")
        #expect(config.port == 4200)
        #expect(config.connectTimeout == 3_000_000)
        #expect(config.streamID == nil)
        #expect(config.passphrase == nil)
        #expect(config.keySize == .aes128)
        #expect(config.cipherMode == .ctr)
        #expect(config.latency == 120_000)
        #expect(config.congestionControl == "live")
        #expect(config.fecConfiguration == nil)
    }

    @Test("Custom configuration applies all fields")
    func customConfig() throws {
        let fecConfig = try FECConfiguration(columns: 5, rows: 2)
        let config = SRTCaller.Configuration(
            host: "10.0.0.1",
            port: 9000,
            connectTimeout: 5_000_000,
            streamID: "#!::r=live/stream1",
            passphrase: "mysecretpassphrase",
            keySize: .aes256,
            cipherMode: .gcm,
            latency: 200_000,
            congestionControl: "file",
            fecConfiguration: fecConfig
        )
        #expect(config.host == "10.0.0.1")
        #expect(config.port == 9000)
        #expect(config.connectTimeout == 5_000_000)
        #expect(config.streamID == "#!::r=live/stream1")
        #expect(config.passphrase == "mysecretpassphrase")
        #expect(config.keySize == .aes256)
        #expect(config.cipherMode == .gcm)
        #expect(config.latency == 200_000)
        #expect(config.congestionControl == "file")
        #expect(config.fecConfiguration != nil)
    }

    @Test("StreamID stored correctly")
    func streamIDStored() {
        let config = SRTCaller.Configuration(
            host: "localhost", port: 4200, streamID: "test-stream")
        #expect(config.streamID == "test-stream")
    }

    // MARK: - Lifecycle

    @Test("Initial state is idle")
    func initialStateIdle() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        let state = await caller.state
        #expect(state == .idle)
    }

    @Test("connect transitions through connecting to handshaking")
    func connectTransitions() async throws {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        try await caller.connect()
        let state = await caller.state
        #expect(state == .handshaking)
    }

    @Test("disconnect transitions to closed")
    func disconnectTransitions() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        await caller.disconnect()
        let state = await caller.state
        #expect(state == .closed)
    }

    @Test("send before connect throws")
    func sendBeforeConnect() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        do {
            _ = try await caller.send([0x01])
            Issue.record("Expected throw")
        } catch let error as SRTConnectionError {
            if case .invalidState = error {
            } else {
                Issue.record("Expected invalidState")
            }
        } catch {
            Issue.record("Expected SRTConnectionError")
        }
    }

    @Test("receive before connect returns nil")
    func receiveBeforeConnect() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        let data = await caller.receive()
        #expect(data == nil)
    }

    @Test("disconnect on closed is no-op")
    func disconnectOnClosed() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        await caller.disconnect()
        let state1 = await caller.state
        #expect(state1 == .closed)
        // Second disconnect should be no-op
        await caller.disconnect()
        let state2 = await caller.state
        #expect(state2 == .closed)
    }

    @Test("Events stream is available")
    func eventsStreamAvailable() async {
        let caller = SRTCaller(
            configuration: .init(host: "127.0.0.1", port: 4200))
        let events = await caller.events
        _ = events
    }
}
