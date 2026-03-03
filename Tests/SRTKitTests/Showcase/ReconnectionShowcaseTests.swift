// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("Reconnection Showcase")
struct ReconnectionShowcaseTests {
    // MARK: - Presets

    @Test("All 4 reconnect policy presets")
    func policyPresets() {
        // Default: moderate retry
        let def = SRTReconnectPolicy.default
        #expect(def.maxAttempts > 0)

        // Aggressive: infinite retries (0 = unlimited), shorter delays
        let agg = SRTReconnectPolicy.aggressive
        #expect(agg.maxAttempts == 0)
        #expect(agg.initialDelayMicroseconds < def.initialDelayMicroseconds)

        // Conservative: fewer retries, longer delays
        let con = SRTReconnectPolicy.conservative
        #expect(con.initialDelayMicroseconds > def.initialDelayMicroseconds)

        // Disabled: no retries
        let dis = SRTReconnectPolicy.disabled
        #expect(dis.maxAttempts == 0)
    }

    @Test("Exponential backoff doubles delay each attempt")
    func exponentialBackoff() {
        let policy = SRTReconnectPolicy(
            maxAttempts: 10,
            initialDelayMicroseconds: 1_000_000,
            maxDelayMicroseconds: 60_000_000,
            backoffMultiplier: 2.0,
            jitter: 0.0)
        let manager = ReconnectionManager(policy: policy)

        // Attempts are 1-based
        let d1 = manager.delayForAttempt(1)
        let d2 = manager.delayForAttempt(2)
        let d3 = manager.delayForAttempt(3)

        #expect(d2 >= d1 * 2)
        #expect(d3 >= d2 * 2)
    }

    @Test("Max delay cap is enforced")
    func maxDelayCap() {
        let policy = SRTReconnectPolicy(
            maxAttempts: 20,
            initialDelayMicroseconds: 1_000_000,
            maxDelayMicroseconds: 10_000_000,
            backoffMultiplier: 2.0,
            jitter: 0.0)
        let manager = ReconnectionManager(policy: policy)

        // After many attempts, delay should cap
        let delay = manager.delayForAttempt(15)
        #expect(delay <= 10_000_000)
    }

    // MARK: - State Machine

    @Test("ReconnectionManager state machine: idle → waiting → exhausted")
    func stateMachineExhausted() {
        var manager = ReconnectionManager(
            policy: SRTReconnectPolicy(
                maxAttempts: 2,
                initialDelayMicroseconds: 100_000,
                maxDelayMicroseconds: 1_000_000,
                backoffMultiplier: 2.0,
                jitter: 0.0))

        #expect(manager.state == .idle)

        // Connection broken → waiting
        let action1 = manager.connectionBroken()
        #expect(manager.state == .waiting)
        if case .waitAndRetry = action1 {
            // Expected
        } else if case .attemptNow = action1 {
            // Also acceptable
        } else {
            Issue.record("Expected waitAndRetry or attemptNow")
        }

        // First attempt fails
        let action2 = manager.attemptFailed()
        if case .waitAndRetry = action2 {
            // Expected — still has attempts
        }

        // Second attempt fails → exhausted
        let action3 = manager.attemptFailed()
        #expect(manager.state == .exhausted)
        if case .giveUp = action3 {
            // Expected
        }
    }

    @Test("ReconnectionManager reset clears state")
    func resetClearsState() {
        var manager = ReconnectionManager(policy: .default)
        _ = manager.connectionBroken()
        #expect(manager.state == .waiting)

        manager.reset()
        #expect(manager.state == .idle)
        #expect(manager.currentAttempt == 0)
    }
}
