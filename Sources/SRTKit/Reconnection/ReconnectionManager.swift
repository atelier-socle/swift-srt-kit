// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Manages automatic reconnection with backoff logic.
///
/// Pure logic component — computes delay times and tracks
/// attempts. Does NOT perform actual connections.
public struct ReconnectionManager: Sendable {
    /// State of the reconnection process.
    public enum State: String, Sendable, Equatable {
        /// Not reconnecting.
        case idle
        /// Waiting for next attempt.
        case waiting
        /// Attempting connection.
        case attempting
        /// Successfully reconnected.
        case reconnected
        /// Max attempts exhausted.
        case exhausted
    }

    /// Action the connection actor should take.
    public enum Action: Sendable, Equatable {
        /// Wait for the specified duration before retrying.
        case waitAndRetry(delayMicroseconds: UInt64)
        /// Attempt connection now.
        case attemptNow
        /// Give up — max attempts reached.
        case giveUp
        /// No action (not in reconnection mode).
        case none
    }

    /// The reconnection policy.
    public let policy: SRTReconnectPolicy

    /// Current state.
    public private(set) var state: State = .idle

    /// Current attempt number (1-based).
    public private(set) var currentAttempt: Int = 0

    /// Total attempts made.
    public private(set) var totalAttempts: Int = 0

    /// Create a reconnection manager.
    ///
    /// - Parameter policy: The reconnection policy.
    public init(policy: SRTReconnectPolicy) {
        self.policy = policy
    }

    /// Notify that the connection was broken.
    ///
    /// Starts the reconnection process.
    ///
    /// - Returns: First action to take.
    public mutating func connectionBroken() -> Action {
        guard policy.initialDelayMicroseconds > 0 else {
            state = .exhausted
            return .giveUp
        }
        currentAttempt = 1
        totalAttempts = 0
        state = .waiting
        let delay = delayForAttempt(currentAttempt)
        return .waitAndRetry(delayMicroseconds: delay)
    }

    /// Notify that a reconnection attempt failed.
    ///
    /// - Returns: Next action (wait or give up).
    public mutating func attemptFailed() -> Action {
        totalAttempts += 1
        currentAttempt += 1

        if policy.maxAttempts > 0 && currentAttempt > policy.maxAttempts {
            state = .exhausted
            return .giveUp
        }

        state = .waiting
        let delay = delayForAttempt(currentAttempt)
        return .waitAndRetry(delayMicroseconds: delay)
    }

    /// Notify that reconnection succeeded.
    public mutating func attemptSucceeded() {
        totalAttempts += 1
        state = .reconnected
    }

    /// Cancel ongoing reconnection.
    public mutating func cancel() {
        state = .idle
        currentAttempt = 0
    }

    /// Compute delay for a given attempt number.
    ///
    /// `delay = min(initialDelay * multiplier^(attempt-1), maxDelay) * (1 +/- jitter)`
    /// Uses deterministic jitter for testability (hash-based).
    ///
    /// - Parameter attempt: Attempt number (1-based).
    /// - Returns: Delay in microseconds.
    public func delayForAttempt(_ attempt: Int) -> UInt64 {
        let exponent = attempt - 1
        var baseDelay = Double(policy.initialDelayMicroseconds)
        for _ in 0..<exponent {
            baseDelay *= policy.backoffMultiplier
        }
        baseDelay = min(baseDelay, Double(policy.maxDelayMicroseconds))

        // Deterministic jitter
        let hash = Double((attempt &* 2_654_435_761) & 0xFFFF) / 65536.0
        let jitterFactor = 1.0 + policy.jitter * (2.0 * hash - 1.0)
        let delay = UInt64(baseDelay * jitterFactor)

        return min(delay, policy.maxDelayMicroseconds)
    }

    /// Reset to idle state.
    public mutating func reset() {
        state = .idle
        currentAttempt = 0
        totalAttempts = 0
    }
}
