// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Configuration for a connection group.
public struct GroupConfiguration: Sendable, Equatable {
    /// Bonding mode.
    public let mode: GroupMode
    /// Link stability timeout in microseconds (default: 40_000 = 40ms).
    public let stabilityTimeout: UInt64
    /// Peer latency in microseconds for timeout calculation (default: 120_000).
    public let peerLatency: UInt64
    /// Maximum number of members (default: 8).
    public let maxMembers: Int

    /// Effective stability timeout: max(peerLatency, stabilityTimeout).
    public var effectiveStabilityTimeout: UInt64 {
        max(peerLatency, stabilityTimeout)
    }

    /// Creates a group configuration.
    ///
    /// - Parameters:
    ///   - mode: Bonding mode.
    ///   - stabilityTimeout: Stability timeout in microseconds.
    ///   - peerLatency: Peer latency in microseconds.
    ///   - maxMembers: Maximum number of members.
    public init(
        mode: GroupMode,
        stabilityTimeout: UInt64 = 40_000,
        peerLatency: UInt64 = 120_000,
        maxMembers: Int = 8
    ) {
        self.mode = mode
        self.stabilityTimeout = stabilityTimeout
        self.peerLatency = peerLatency
        self.maxMembers = maxMembers
    }
}
