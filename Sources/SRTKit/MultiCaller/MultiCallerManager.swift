// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Manages simultaneous streaming to multiple SRT destinations.
///
/// Pure logic component — tracks destinations, computes actions,
/// aggregates statistics. Does NOT perform actual connections or
/// send data.
public struct MultiCallerManager: Sendable {
    /// Action for a specific destination.
    public enum DestinationAction: Sendable, Equatable {
        /// Connect to this destination.
        case connect(destinationID: String)
        /// Disconnect from this destination.
        case disconnect(destinationID: String)
        /// Reconnect this destination.
        case reconnect(destinationID: String, delayMicroseconds: UInt64)
        /// Send data to this destination.
        case send(destinationID: String)
        /// No action for this destination.
        case none
    }

    /// Event from the multi-caller manager.
    public enum Event: Sendable {
        /// Destination added.
        case destinationAdded(String)
        /// Destination removed.
        case destinationRemoved(String)
        /// Destination state changed.
        case destinationStateChanged(
            id: String, from: SRTConnectionState, to: SRTConnectionState)
        /// Destination failed (isolated).
        case destinationFailed(id: String, reason: String)
        /// All destinations failed.
        case allDestinationsFailed
    }

    private var destinationList: [SRTDestination] = []
    private var reconnectionManagers: [String: ReconnectionManager] = [:]

    /// Create a multi-caller manager.
    public init() {}

    /// Add a destination.
    ///
    /// - Parameter destination: The destination to add.
    /// - Throws: `MultiCallerError` if duplicate ID.
    public mutating func addDestination(
        _ destination: SRTDestination
    ) throws {
        if destinationList.contains(where: { $0.id == destination.id }) {
            throw MultiCallerError.duplicateDestination(id: destination.id)
        }
        destinationList.append(destination)
        reconnectionManagers[destination.id] = ReconnectionManager(
            policy: destination.reconnectPolicy)
    }

    /// Remove a destination by ID.
    ///
    /// - Parameter id: Destination ID.
    public mutating func removeDestination(id: String) {
        destinationList.removeAll { $0.id == id }
        reconnectionManagers.removeValue(forKey: id)
    }

    /// Enable or disable a destination.
    ///
    /// - Parameters:
    ///   - id: Destination ID.
    ///   - enabled: Whether to enable.
    public mutating func setDestinationEnabled(id: String, enabled: Bool) {
        guard let index = destinationList.firstIndex(where: { $0.id == id })
        else { return }
        destinationList[index].enabled = enabled
    }

    /// Get all destinations.
    public var destinations: [SRTDestination] {
        destinationList
    }

    /// Get enabled destinations.
    public var enabledDestinations: [SRTDestination] {
        destinationList.filter { $0.enabled }
    }

    /// Get a specific destination.
    ///
    /// - Parameter id: Destination ID.
    /// - Returns: Destination, or nil if not found.
    public func destination(id: String) -> SRTDestination? {
        destinationList.first { $0.id == id }
    }

    /// Update destination state.
    ///
    /// - Parameters:
    ///   - id: Destination ID.
    ///   - state: New state.
    /// - Returns: Event describing the state change.
    public mutating func updateState(
        id: String, to state: SRTConnectionState
    ) -> Event? {
        guard let index = destinationList.firstIndex(where: { $0.id == id })
        else { return nil }
        let oldState = destinationList[index].state
        destinationList[index].state = state
        return .destinationStateChanged(id: id, from: oldState, to: state)
    }

    /// Record that a destination's connection broke.
    ///
    /// - Parameter id: Destination ID.
    /// - Returns: Reconnection action (or give up).
    public mutating func destinationBroken(
        id: String
    ) -> DestinationAction {
        guard let index = destinationList.firstIndex(where: { $0.id == id })
        else { return .none }
        destinationList[index].state = .broken

        guard var manager = reconnectionManagers[id] else { return .none }
        let action = manager.connectionBroken()
        reconnectionManagers[id] = manager

        switch action {
        case .waitAndRetry(let delay):
            return .reconnect(destinationID: id, delayMicroseconds: delay)
        case .giveUp:
            return .disconnect(destinationID: id)
        case .attemptNow, .none:
            return .none
        }
    }

    /// Record that a reconnection attempt failed.
    ///
    /// - Parameter id: Destination ID.
    /// - Returns: Next reconnection action.
    public mutating func reconnectFailed(
        id: String
    ) -> DestinationAction {
        guard var manager = reconnectionManagers[id] else { return .none }
        let action = manager.attemptFailed()
        reconnectionManagers[id] = manager

        switch action {
        case .waitAndRetry(let delay):
            return .reconnect(destinationID: id, delayMicroseconds: delay)
        case .giveUp:
            return .disconnect(destinationID: id)
        case .attemptNow, .none:
            return .none
        }
    }

    /// Record that a destination reconnected.
    ///
    /// - Parameter id: Destination ID.
    public mutating func reconnectSucceeded(id: String) {
        guard let index = destinationList.firstIndex(where: { $0.id == id })
        else { return }
        destinationList[index].state = .connected

        guard var manager = reconnectionManagers[id] else { return }
        manager.attemptSucceeded()
        reconnectionManagers[id] = manager
    }

    /// Get actions for sending data.
    ///
    /// Returns send actions for all connected and enabled destinations.
    ///
    /// - Returns: Array of send actions.
    public func prepareSend() -> [DestinationAction] {
        destinationList
            .filter { $0.enabled && $0.state.isActive }
            .map { .send(destinationID: $0.id) }
    }

    /// Aggregated statistics across all enabled destinations.
    public var aggregatedStatistics: SRTStatistics {
        var agg = SRTStatistics()
        for dest in destinationList where dest.enabled {
            agg.packetsSent += dest.statistics.packetsSent
            agg.packetsReceived += dest.statistics.packetsReceived
            agg.packetsSentLost += dest.statistics.packetsSentLost
            agg.packetsReceivedLost += dest.statistics.packetsReceivedLost
            agg.packetsRetransmitted += dest.statistics.packetsRetransmitted
            agg.bytesSent += dest.statistics.bytesSent
            agg.bytesReceived += dest.statistics.bytesReceived
        }
        return agg
    }

    /// Number of connected destinations.
    public var connectedCount: Int {
        destinationList.filter { $0.state.isActive }.count
    }

    /// Number of enabled destinations.
    public var enabledCount: Int {
        destinationList.filter { $0.enabled }.count
    }

    /// Whether all destinations have failed.
    public var allFailed: Bool {
        guard !destinationList.isEmpty else { return false }
        return destinationList.allSatisfy { $0.state.isTerminal }
    }
}
