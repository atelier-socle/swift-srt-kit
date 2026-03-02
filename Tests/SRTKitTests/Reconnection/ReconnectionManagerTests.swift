// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("ReconnectionManager Tests")
struct ReconnectionManagerTests {
    // MARK: - Basic flow

    @Test("Initial state is idle")
    func initialStateIdle() {
        let manager = ReconnectionManager(policy: .default)
        #expect(manager.state == .idle)
        #expect(manager.currentAttempt == 0)
    }

    @Test("connectionBroken returns waitAndRetry")
    func connectionBrokenWait() {
        var manager = ReconnectionManager(policy: .default)
        let action = manager.connectionBroken()
        if case .waitAndRetry(let delay) = action {
            #expect(delay > 0)
        } else {
            Issue.record("Expected waitAndRetry")
        }
        #expect(manager.state == .waiting)
        #expect(manager.currentAttempt == 1)
    }

    @Test("attemptFailed increments attempt counter")
    func attemptFailedIncrements() {
        var manager = ReconnectionManager(policy: .default)
        _ = manager.connectionBroken()
        _ = manager.attemptFailed()
        #expect(manager.currentAttempt == 2)
        #expect(manager.totalAttempts == 1)
    }

    @Test("attemptSucceeded sets state to reconnected")
    func attemptSucceeded() {
        var manager = ReconnectionManager(policy: .default)
        _ = manager.connectionBroken()
        manager.attemptSucceeded()
        #expect(manager.state == .reconnected)
    }

    @Test("cancel sets state to idle")
    func cancelResetsState() {
        var manager = ReconnectionManager(policy: .default)
        _ = manager.connectionBroken()
        manager.cancel()
        #expect(manager.state == .idle)
        #expect(manager.currentAttempt == 0)
    }

    // MARK: - Backoff

    @Test("Delay doubles on each attempt (multiplier=2)")
    func delayDoublesEachAttempt() {
        let policy = SRTReconnectPolicy(
            initialDelayMicroseconds: 1_000_000,
            maxDelayMicroseconds: 100_000_000,
            backoffMultiplier: 2.0,
            jitter: 0.0
        )
        let manager = ReconnectionManager(policy: policy)
        let d1 = manager.delayForAttempt(1)
        let d2 = manager.delayForAttempt(2)
        let d3 = manager.delayForAttempt(3)
        #expect(d1 == 1_000_000)
        #expect(d2 == 2_000_000)
        #expect(d3 == 4_000_000)
    }

    @Test("Delay capped at maxDelay")
    func delayCapped() {
        let policy = SRTReconnectPolicy(
            initialDelayMicroseconds: 1_000_000,
            maxDelayMicroseconds: 5_000_000,
            backoffMultiplier: 2.0,
            jitter: 0.0
        )
        let manager = ReconnectionManager(policy: policy)
        let d10 = manager.delayForAttempt(10)
        #expect(d10 == 5_000_000)
    }

    @Test("Jitter applied (deterministic, within range)")
    func jitterApplied() {
        let policy = SRTReconnectPolicy(
            initialDelayMicroseconds: 1_000_000,
            maxDelayMicroseconds: 100_000_000,
            backoffMultiplier: 2.0,
            jitter: 0.1
        )
        let manager = ReconnectionManager(policy: policy)
        let delay = manager.delayForAttempt(1)
        // With 10% jitter, delay should be in [900_000, 1_100_000]
        #expect(delay >= 900_000)
        #expect(delay <= 1_100_000)
    }

    @Test("delayForAttempt(1) is initial delay with jitter")
    func delayForAttempt1() {
        let policy = SRTReconnectPolicy(
            initialDelayMicroseconds: 2_000_000,
            maxDelayMicroseconds: 100_000_000,
            backoffMultiplier: 2.0,
            jitter: 0.1
        )
        let manager = ReconnectionManager(policy: policy)
        let delay = manager.delayForAttempt(1)
        #expect(delay >= 1_800_000)
        #expect(delay <= 2_200_000)
    }

    @Test("delayForAttempt(3) is initialDelay x 4 with jitter")
    func delayForAttempt3() {
        let policy = SRTReconnectPolicy(
            initialDelayMicroseconds: 1_000_000,
            maxDelayMicroseconds: 100_000_000,
            backoffMultiplier: 2.0,
            jitter: 0.1
        )
        let manager = ReconnectionManager(policy: policy)
        let delay = manager.delayForAttempt(3)
        // base = 1M * 2^2 = 4M, jitter range: [3.6M, 4.4M]
        #expect(delay >= 3_600_000)
        #expect(delay <= 4_400_000)
    }

    // MARK: - Max attempts

    @Test("After maxAttempts gives up")
    func maxAttemptsGiveUp() {
        var manager = ReconnectionManager(
            policy: SRTReconnectPolicy(maxAttempts: 2))
        _ = manager.connectionBroken()  // attempt 1
        let a1 = manager.attemptFailed()  // attempt 2
        if case .waitAndRetry = a1 {
        } else {
            Issue.record("Expected waitAndRetry for attempt 2")
        }
        let a2 = manager.attemptFailed()  // attempt 3 > max
        #expect(a2 == .giveUp)
        #expect(manager.state == .exhausted)
    }

    @Test("maxAttempts=0 (infinite) never gives up")
    func infiniteAttempts() {
        var manager = ReconnectionManager(
            policy: SRTReconnectPolicy(maxAttempts: 0))
        _ = manager.connectionBroken()
        for _ in 0..<100 {
            let action = manager.attemptFailed()
            if case .waitAndRetry = action {
            } else {
                Issue.record("Expected waitAndRetry for infinite policy")
                return
            }
        }
    }

    // MARK: - Reset

    @Test("reset clears state and attempts")
    func resetClears() {
        var manager = ReconnectionManager(policy: .default)
        _ = manager.connectionBroken()
        _ = manager.attemptFailed()
        manager.reset()
        #expect(manager.state == .idle)
        #expect(manager.currentAttempt == 0)
        #expect(manager.totalAttempts == 0)
    }

    @Test("After reset, connectionBroken works again")
    func afterResetWorks() {
        var manager = ReconnectionManager(policy: .default)
        _ = manager.connectionBroken()
        manager.reset()
        let action = manager.connectionBroken()
        if case .waitAndRetry = action {
        } else {
            Issue.record("Expected waitAndRetry after reset")
        }
        #expect(manager.currentAttempt == 1)
    }

    // MARK: - Disabled policy

    @Test("Disabled policy gives up immediately")
    func disabledPolicyGivesUp() {
        var manager = ReconnectionManager(policy: .disabled)
        let action = manager.connectionBroken()
        #expect(action == .giveUp)
        #expect(manager.state == .exhausted)
    }
}
