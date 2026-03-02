// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A member link in a connection group.
///
/// Tracks the link's status, weight, performance metrics,
/// and timing information for stability detection.
public struct GroupMember: Sendable, Identifiable {
    /// Unique identifier for this member.
    public let id: UInt32
    /// Remote host.
    public let host: String
    /// Remote port.
    public let port: Int
    /// Link weight (higher = preferred). Default: 1.
    public let weight: Int
    /// Current link status.
    public var status: LinkStatus
    /// Time of last peer response in microseconds.
    public var lastResponseTime: UInt64?
    /// Time the link was activated in microseconds.
    public var activationTime: UInt64?
    /// Current sequence number on this link.
    public var currentSequence: SequenceNumber
    /// Current message number (for balancing mode).
    public var currentMessageNumber: UInt32
    /// Estimated bandwidth in bits/second.
    public var estimatedBandwidth: UInt64
    /// Current load (packets in flight).
    public var currentLoad: Int

    /// Creates a group member.
    ///
    /// - Parameters:
    ///   - id: Unique identifier.
    ///   - host: Remote host.
    ///   - port: Remote port.
    ///   - weight: Link weight (default: 1).
    public init(
        id: UInt32,
        host: String,
        port: Int,
        weight: Int = 1
    ) {
        self.id = id
        self.host = host
        self.port = port
        self.weight = weight
        self.status = .pending
        self.lastResponseTime = nil
        self.activationTime = nil
        self.currentSequence = SequenceNumber(0)
        self.currentMessageNumber = 0
        self.estimatedBandwidth = 0
        self.currentLoad = 0
    }
}
