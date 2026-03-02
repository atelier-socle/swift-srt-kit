// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTReconnectPolicy Tests")
struct SRTReconnectPolicyTests {
    @Test("Default preset values")
    func defaultPreset() {
        let policy = SRTReconnectPolicy.default
        #expect(policy.maxAttempts == 10)
        #expect(policy.initialDelayMicroseconds == 1_000_000)
        #expect(policy.maxDelayMicroseconds == 30_000_000)
        #expect(policy.backoffMultiplier == 2.0)
        #expect(policy.jitter == 0.1)
    }

    @Test("Aggressive preset values")
    func aggressivePreset() {
        let policy = SRTReconnectPolicy.aggressive
        #expect(policy.maxAttempts == 0)
        #expect(policy.initialDelayMicroseconds == 500_000)
        #expect(policy.maxDelayMicroseconds == 10_000_000)
        #expect(policy.backoffMultiplier == 1.5)
    }

    @Test("Conservative preset values")
    func conservativePreset() {
        let policy = SRTReconnectPolicy.conservative
        #expect(policy.maxAttempts == 5)
        #expect(policy.initialDelayMicroseconds == 2_000_000)
        #expect(policy.maxDelayMicroseconds == 60_000_000)
        #expect(policy.backoffMultiplier == 3.0)
    }

    @Test("Disabled preset: no reconnection")
    func disabledPreset() {
        let policy = SRTReconnectPolicy.disabled
        #expect(policy.maxAttempts == 0)
        #expect(policy.initialDelayMicroseconds == 0)
        #expect(policy.maxDelayMicroseconds == 0)
        #expect(policy.jitter == 0.0)
    }

    @Test("Equatable: same values are equal")
    func equatableSame() {
        let a = SRTReconnectPolicy.default
        let b = SRTReconnectPolicy.default
        #expect(a == b)
    }

    @Test("Equatable: different values are not equal")
    func equatableDifferent() {
        #expect(SRTReconnectPolicy.default != SRTReconnectPolicy.aggressive)
    }

    @Test("Custom init sets all fields")
    func customInit() {
        let policy = SRTReconnectPolicy(
            maxAttempts: 3,
            initialDelayMicroseconds: 500_000,
            maxDelayMicroseconds: 5_000_000,
            backoffMultiplier: 1.5,
            jitter: 0.2
        )
        #expect(policy.maxAttempts == 3)
        #expect(policy.initialDelayMicroseconds == 500_000)
        #expect(policy.maxDelayMicroseconds == 5_000_000)
        #expect(policy.backoffMultiplier == 1.5)
        #expect(policy.jitter == 0.2)
    }
}
