// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Reconnection policy with exponential backoff and jitter.
///
/// Controls how and when a caller re-attempts connection
/// after a connection break.
public struct SRTReconnectPolicy: Sendable, Equatable {
    /// Maximum reconnection attempts (0 = infinite).
    public let maxAttempts: Int

    /// Initial delay before first retry in microseconds.
    public let initialDelayMicroseconds: UInt64

    /// Maximum delay cap in microseconds.
    public let maxDelayMicroseconds: UInt64

    /// Backoff multiplier (default: 2.0).
    public let backoffMultiplier: Double

    /// Jitter factor (0.0–1.0) — randomizes delay to avoid thundering herd.
    public let jitter: Double

    /// Create a reconnection policy.
    ///
    /// - Parameters:
    ///   - maxAttempts: Maximum attempts (0 = infinite).
    ///   - initialDelayMicroseconds: Initial delay in microseconds.
    ///   - maxDelayMicroseconds: Maximum delay cap in microseconds.
    ///   - backoffMultiplier: Multiplier for exponential backoff.
    ///   - jitter: Jitter factor (0.0–1.0).
    public init(
        maxAttempts: Int = 10,
        initialDelayMicroseconds: UInt64 = 1_000_000,
        maxDelayMicroseconds: UInt64 = 30_000_000,
        backoffMultiplier: Double = 2.0,
        jitter: Double = 0.1
    ) {
        self.maxAttempts = maxAttempts
        self.initialDelayMicroseconds = initialDelayMicroseconds
        self.maxDelayMicroseconds = maxDelayMicroseconds
        self.backoffMultiplier = backoffMultiplier
        self.jitter = jitter
    }

    /// Default policy: 10 attempts, 1s initial, 30s max, 2x backoff.
    public static let `default` = SRTReconnectPolicy()

    /// Aggressive: infinite attempts, 500ms initial, 10s max, 1.5x backoff.
    public static let aggressive = SRTReconnectPolicy(
        maxAttempts: 0,
        initialDelayMicroseconds: 500_000,
        maxDelayMicroseconds: 10_000_000,
        backoffMultiplier: 1.5,
        jitter: 0.15
    )

    /// Conservative: 5 attempts, 2s initial, 60s max, 3x backoff.
    public static let conservative = SRTReconnectPolicy(
        maxAttempts: 5,
        initialDelayMicroseconds: 2_000_000,
        maxDelayMicroseconds: 60_000_000,
        backoffMultiplier: 3.0,
        jitter: 0.2
    )

    /// Disabled: no reconnection.
    public static let disabled = SRTReconnectPolicy(
        maxAttempts: 0,
        initialDelayMicroseconds: 0,
        maxDelayMicroseconds: 0,
        backoffMultiplier: 1.0,
        jitter: 0.0
    )
}
