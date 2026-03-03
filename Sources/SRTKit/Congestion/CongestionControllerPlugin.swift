// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Extended plugin interface for custom congestion controllers.
///
/// This builds on the existing CongestionController protocol from
/// Session 8 by adding event-based dispatch and network snapshots.
/// Implementers receive typed events with full network context and
/// return typed decisions.
///
/// Built-in implementations: LiveCC, FileCC, AdaptiveCC.
public protocol CongestionControllerPlugin: Sendable {
    /// Plugin name (used for factory registration and logging).
    var name: String { get }

    /// Process a congestion event and return a decision.
    ///
    /// - Parameters:
    ///   - event: The congestion event.
    ///   - snapshot: Current network state.
    /// - Returns: Decision for the connection layer.
    mutating func processEvent(
        _ event: CongestionEvent,
        snapshot: NetworkSnapshot
    ) -> CongestionDecision

    /// Current congestion window size in packets.
    var congestionWindow: Int { get }

    /// Current sending period in microseconds.
    var sendingPeriodMicroseconds: UInt64 { get }

    /// Reset the controller state.
    mutating func reset()
}
