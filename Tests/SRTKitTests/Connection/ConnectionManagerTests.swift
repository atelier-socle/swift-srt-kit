// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("ConnectionManager Tests")
struct ConnectionManagerTests {
    // MARK: - Keepalive

    @Test("Fresh manager with no activity returns none")
    func freshManagerReturnsNone() {
        let manager = ConnectionManager()
        #expect(manager.check(at: 1_000_000) == .none)
    }

    @Test("No response yet after peer received returns sendKeepalive after interval")
    func sendKeepaliveAfterInterval() {
        var manager = ConnectionManager(
            configuration: .init(keepaliveInterval: 1_000_000))
        manager.peerResponseReceived(at: 0)
        #expect(manager.check(at: 500_000) == .none)
        #expect(manager.check(at: 1_000_000) == .sendKeepalive)
    }

    @Test("After keepaliveTimeout with no response returns timeout")
    func timeoutAfterNoResponse() {
        var manager = ConnectionManager(
            configuration: .init(
                keepaliveInterval: 1_000_000,
                keepaliveTimeout: 5_000_000))
        manager.peerResponseReceived(at: 0)
        #expect(manager.check(at: 5_000_000) == .timeout)
    }

    @Test("peerResponseReceived resets timeout")
    func peerResponseResetsTimeout() {
        var manager = ConnectionManager(
            configuration: .init(
                keepaliveInterval: 1_000_000,
                keepaliveTimeout: 5_000_000))
        manager.peerResponseReceived(at: 0)
        // At 4s, nearly timed out
        #expect(manager.check(at: 4_000_000) == .sendKeepalive)
        // Peer responds at 4s
        manager.peerResponseReceived(at: 4_000_000)
        // Now at 5s, only 1s since response — not timed out
        #expect(manager.check(at: 5_000_000) == .sendKeepalive)
        // At 9s, timed out (5s since 4s response)
        #expect(manager.check(at: 9_000_000) == .timeout)
    }

    @Test("keepaliveSent updates last send time")
    func keepaliveSentUpdates() {
        var manager = ConnectionManager(
            configuration: .init(keepaliveInterval: 1_000_000))
        manager.peerResponseReceived(at: 0)
        // After interval, should send keepalive
        #expect(manager.check(at: 1_000_000) == .sendKeepalive)
        // Record keepalive sent
        manager.keepaliveSent(at: 1_000_000)
        // Right after sending, should not send again
        #expect(manager.check(at: 1_500_000) == .none)
        // After another interval, send again
        #expect(manager.check(at: 2_000_000) == .sendKeepalive)
    }

    @Test("Multiple keepalives before timeout still sends keepalive")
    func multipleKeepalivesBeforeTimeout() {
        var manager = ConnectionManager(
            configuration: .init(
                keepaliveInterval: 1_000_000,
                keepaliveTimeout: 5_000_000))
        manager.peerResponseReceived(at: 0)
        // Send keepalives at 1s, 2s, 3s — peer not responding
        for t: UInt64 in [1_000_000, 2_000_000, 3_000_000] {
            #expect(manager.check(at: t) == .sendKeepalive)
            manager.keepaliveSent(at: t)
        }
        // At 4s still sending keepalives
        #expect(manager.check(at: 4_000_000) == .sendKeepalive)
        // At 5s, timeout
        #expect(manager.check(at: 5_000_000) == .timeout)
    }

    // MARK: - Shutdown

    @Test("beginShutdown sets isShuttingDown")
    func beginShutdownSetsFlag() {
        var manager = ConnectionManager()
        #expect(!manager.isShuttingDown)
        manager.beginShutdown(at: 1_000_000)
        #expect(manager.isShuttingDown)
    }

    @Test("After shutdownTimeout returns shutdownComplete")
    func shutdownComplete() {
        var manager = ConnectionManager(
            configuration: .init(shutdownTimeout: 3_000_000))
        manager.beginShutdown(at: 1_000_000)
        #expect(manager.check(at: 2_000_000) == .initiateShutdown)
        #expect(manager.check(at: 4_000_000) == .shutdownComplete)
    }

    @Test("Before shutdownTimeout returns initiateShutdown")
    func shutdownInProgress() {
        var manager = ConnectionManager(
            configuration: .init(shutdownTimeout: 3_000_000))
        manager.beginShutdown(at: 0)
        #expect(manager.check(at: 1_000_000) == .initiateShutdown)
        #expect(manager.check(at: 2_999_999) == .initiateShutdown)
    }

    @Test("Shutdown state is independent of keepalive")
    func shutdownIndependentOfKeepalive() {
        var manager = ConnectionManager(
            configuration: .init(
                keepaliveInterval: 1_000_000,
                keepaliveTimeout: 5_000_000,
                shutdownTimeout: 2_000_000))
        manager.peerResponseReceived(at: 0)
        manager.beginShutdown(at: 1_000_000)
        // Even though keepalive would be due, shutdown takes priority
        #expect(manager.check(at: 2_000_000) == .initiateShutdown)
        #expect(manager.check(at: 3_000_000) == .shutdownComplete)
    }

    // MARK: - Timing

    @Test("timeSinceLastResponse returns correct duration")
    func timeSinceLastResponse() {
        var manager = ConnectionManager()
        #expect(manager.timeSinceLastResponse(at: 1_000_000) == nil)
        manager.peerResponseReceived(at: 5_000_000)
        #expect(manager.timeSinceLastResponse(at: 7_000_000) == 2_000_000)
    }

    @Test("lastPeerResponse tracks correctly")
    func lastPeerResponseTracking() {
        var manager = ConnectionManager()
        #expect(manager.lastPeerResponse == nil)
        manager.peerResponseReceived(at: 100)
        #expect(manager.lastPeerResponse == 100)
        manager.peerResponseReceived(at: 200)
        #expect(manager.lastPeerResponse == 200)
    }

    @Test("Default configuration has expected values")
    func defaultConfiguration() {
        let config = ConnectionManager.Configuration()
        #expect(config.keepaliveInterval == 1_000_000)
        #expect(config.keepaliveTimeout == 5_000_000)
        #expect(config.shutdownTimeout == 3_000_000)
    }

    @Test("Custom configuration applies all fields")
    func customConfiguration() {
        let config = ConnectionManager.Configuration(
            keepaliveInterval: 500_000,
            keepaliveTimeout: 2_000_000,
            shutdownTimeout: 1_000_000)
        #expect(config.keepaliveInterval == 500_000)
        #expect(config.keepaliveTimeout == 2_000_000)
        #expect(config.shutdownTimeout == 1_000_000)
    }
}
