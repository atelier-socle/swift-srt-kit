// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A destination in a multi-caller configuration.
///
/// Tracks the state, statistics, and reconnection policy
/// for a single destination independently.
public struct SRTDestination: Sendable, Identifiable, Equatable {
    /// Unique label for this destination.
    public let id: String

    /// Remote host.
    public let host: String

    /// Remote port.
    public let port: Int

    /// Current connection state.
    public var state: SRTConnectionState

    /// Per-destination statistics.
    public var statistics: SRTStatistics

    /// Reconnection policy for this destination.
    public let reconnectPolicy: SRTReconnectPolicy

    /// StreamID for this destination.
    public let streamID: String?

    /// Weight (for prioritization, higher = more important).
    public let weight: Int

    /// Whether this destination is enabled.
    public var enabled: Bool

    /// Create a destination.
    ///
    /// - Parameters:
    ///   - id: Unique label.
    ///   - host: Remote host.
    ///   - port: Remote port.
    ///   - reconnectPolicy: Reconnection policy.
    ///   - streamID: Optional StreamID.
    ///   - weight: Priority weight.
    ///   - enabled: Whether enabled.
    public init(
        id: String,
        host: String,
        port: Int,
        reconnectPolicy: SRTReconnectPolicy = .default,
        streamID: String? = nil,
        weight: Int = 1,
        enabled: Bool = true
    ) {
        self.id = id
        self.host = host
        self.port = port
        self.state = .idle
        self.statistics = SRTStatistics()
        self.reconnectPolicy = reconnectPolicy
        self.streamID = streamID
        self.weight = weight
        self.enabled = enabled
    }
}
