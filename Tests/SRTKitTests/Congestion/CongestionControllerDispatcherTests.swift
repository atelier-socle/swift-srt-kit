// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

/// A simple test plugin that returns configurable decisions.
private struct TestPlugin: CongestionControllerPlugin {
    var name: String
    var decision: CongestionDecision
    var _congestionWindow: Int = 100
    var _sendingPeriod: UInt64 = 0
    var processCount: Int = 0

    var congestionWindow: Int { _congestionWindow }
    var sendingPeriodMicroseconds: UInt64 { _sendingPeriod }

    init(
        name: String = "test",
        decision: CongestionDecision = .noChange
    ) {
        self.name = name
        self.decision = decision
    }

    mutating func processEvent(
        _ event: CongestionEvent,
        snapshot: NetworkSnapshot
    ) -> CongestionDecision {
        processCount += 1
        return decision
    }

    mutating func reset() {
        processCount = 0
    }
}

@Suite("CongestionControllerDispatcher Tests")
struct CongestionControllerDispatcherTests {
    private let defaultSnapshot = NetworkSnapshot()

    // MARK: - Basic dispatch

    @Test("dispatch routes event to plugin and returns decision")
    func dispatchRoutes() {
        let decision = CongestionDecision(congestionWindow: 256)
        var dispatcher = CongestionControllerDispatcher(
            plugin: TestPlugin(decision: decision))
        let result = dispatcher.dispatch(
            event: .tick(currentTime: 0), snapshot: defaultSnapshot)
        #expect(result == decision)
    }

    @Test("eventsDispatched increments")
    func eventsDispatchedIncrements() {
        var dispatcher = CongestionControllerDispatcher(
            plugin: TestPlugin())
        _ = dispatcher.dispatch(
            event: .tick(currentTime: 0), snapshot: defaultSnapshot)
        _ = dispatcher.dispatch(
            event: .tick(currentTime: 10_000), snapshot: defaultSnapshot)
        #expect(dispatcher.eventsDispatched == 2)
    }

    @Test("decisionsWithChanges counts only non-noChange")
    func decisionsWithChanges() {
        var dispatcher = CongestionControllerDispatcher(
            plugin: TestPlugin(
                decision: CongestionDecision(congestionWindow: 50)))
        _ = dispatcher.dispatch(
            event: .tick(currentTime: 0), snapshot: defaultSnapshot)
        #expect(dispatcher.decisionsWithChanges == 1)

        // Swap to a plugin that returns noChange
        dispatcher.swapPlugin(TestPlugin(decision: .noChange))
        _ = dispatcher.dispatch(
            event: .tick(currentTime: 10_000), snapshot: defaultSnapshot)
        #expect(dispatcher.decisionsWithChanges == 1)
    }

    @Test("lastDecision updated after dispatch")
    func lastDecisionUpdated() {
        var dispatcher = CongestionControllerDispatcher(
            plugin: TestPlugin())
        #expect(dispatcher.lastDecision == nil)
        _ = dispatcher.dispatch(
            event: .connectionClosing, snapshot: defaultSnapshot)
        #expect(dispatcher.lastDecision == .noChange)
    }

    // MARK: - Plugin swap

    @Test("swapPlugin changes activePluginName")
    func swapPluginChangesName() {
        var dispatcher = CongestionControllerDispatcher(
            plugin: TestPlugin(name: "alpha"))
        #expect(dispatcher.activePluginName == "alpha")
        dispatcher.swapPlugin(TestPlugin(name: "beta"))
        #expect(dispatcher.activePluginName == "beta")
    }

    @Test("After swap, events go to new plugin")
    func afterSwapEventsGoToNewPlugin() {
        let d1 = CongestionDecision(congestionWindow: 100)
        let d2 = CongestionDecision(congestionWindow: 200)
        var dispatcher = CongestionControllerDispatcher(
            plugin: TestPlugin(name: "p1", decision: d1))

        let r1 = dispatcher.dispatch(
            event: .tick(currentTime: 0), snapshot: defaultSnapshot)
        #expect(r1 == d1)

        dispatcher.swapPlugin(TestPlugin(name: "p2", decision: d2))
        let r2 = dispatcher.dispatch(
            event: .tick(currentTime: 10_000), snapshot: defaultSnapshot)
        #expect(r2 == d2)
    }

    // MARK: - Recent events

    @Test("recentEvents records dispatched events")
    func recentEventsRecords() {
        var dispatcher = CongestionControllerDispatcher(
            plugin: TestPlugin())
        _ = dispatcher.dispatch(
            event: .connectionEstablished(initialRTTMicroseconds: 1000),
            snapshot: defaultSnapshot)
        _ = dispatcher.dispatch(
            event: .tick(currentTime: 5000), snapshot: defaultSnapshot)
        #expect(dispatcher.recentEvents.count == 2)
        #expect(
            dispatcher.recentEvents[0]
                == .connectionEstablished(initialRTTMicroseconds: 1000))
    }

    @Test("recentEvents capped at 100")
    func recentEventsCapped() {
        var dispatcher = CongestionControllerDispatcher(
            plugin: TestPlugin())
        for i: UInt64 in 0..<150 {
            _ = dispatcher.dispatch(
                event: .tick(currentTime: i * 10_000),
                snapshot: defaultSnapshot)
        }
        #expect(dispatcher.recentEvents.count == 100)
        #expect(dispatcher.eventsDispatched == 150)
    }

    // MARK: - Integration with AdaptiveCC

    @Test("Dispatch with AdaptiveCC plugin")
    func dispatchWithAdaptive() {
        var dispatcher = CongestionControllerDispatcher(
            plugin: AdaptiveCC())
        #expect(dispatcher.activePluginName == "adaptive")

        let result = dispatcher.dispatch(
            event: .connectionEstablished(initialRTTMicroseconds: 20_000),
            snapshot: defaultSnapshot)
        #expect(result.congestionWindow != nil)
    }
}
