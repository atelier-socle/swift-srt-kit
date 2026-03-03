// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Routes congestion events to the active controller and collects decisions.
///
/// Sits between the connection layer and the CC plugin. Handles:
/// - Event dispatch to the active CC
/// - Decision aggregation
/// - CC hot-swap (change CC at runtime)
/// - Event logging for diagnostics
public struct CongestionControllerDispatcher: Sendable {
    private var plugin: any CongestionControllerPlugin
    private var _eventsDispatched: Int = 0
    private var _decisionsWithChanges: Int = 0
    private var _lastDecision: CongestionDecision?
    private var _recentEvents: [CongestionEvent] = []

    /// Maximum number of recent events to keep.
    private static let maxRecentEvents = 100

    /// Create a dispatcher with an initial CC plugin.
    ///
    /// - Parameter plugin: The initial congestion controller plugin.
    public init(plugin: any CongestionControllerPlugin) {
        self.plugin = plugin
    }

    /// Dispatch an event to the active CC.
    ///
    /// - Parameters:
    ///   - event: The congestion event.
    ///   - snapshot: Current network state.
    /// - Returns: Decision from the CC.
    public mutating func dispatch(
        event: CongestionEvent,
        snapshot: NetworkSnapshot
    ) -> CongestionDecision {
        _eventsDispatched += 1
        appendEvent(event)

        let decision = plugin.processEvent(event, snapshot: snapshot)
        _lastDecision = decision

        if decision != .noChange {
            _decisionsWithChanges += 1
        }

        return decision
    }

    /// Swap the active CC plugin (e.g., switching from live to file mode).
    ///
    /// - Parameter plugin: The new congestion controller plugin.
    public mutating func swapPlugin(_ plugin: any CongestionControllerPlugin) {
        self.plugin = plugin
    }

    /// Name of the currently active CC.
    public var activePluginName: String {
        plugin.name
    }

    /// Total events dispatched.
    public var eventsDispatched: Int { _eventsDispatched }

    /// Total decisions that changed something (non-noChange).
    public var decisionsWithChanges: Int { _decisionsWithChanges }

    /// Last decision returned.
    public var lastDecision: CongestionDecision? { _lastDecision }

    /// Event history (last N events for diagnostics).
    ///
    /// Capped at 100 entries.
    public var recentEvents: [CongestionEvent] { _recentEvents }

    // MARK: - Private

    private mutating func appendEvent(_ event: CongestionEvent) {
        _recentEvents.append(event)
        if _recentEvents.count > Self.maxRecentEvents {
            _recentEvents.removeFirst(
                _recentEvents.count - Self.maxRecentEvents)
        }
    }
}
