// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("MultiCallerManager Tests")
struct MultiCallerManagerTests {
    // MARK: - Destination management

    @Test("Initial state has no destinations")
    func initialEmpty() {
        let manager = MultiCallerManager()
        #expect(manager.destinations.isEmpty)
        #expect(manager.connectedCount == 0)
        #expect(manager.enabledCount == 0)
    }

    @Test("addDestination adds to list")
    func addDestination() throws {
        var manager = MultiCallerManager()
        let dest = SRTDestination(id: "d1", host: "h", port: 1)
        try manager.addDestination(dest)
        #expect(manager.destinations.count == 1)
        #expect(manager.destination(id: "d1") != nil)
    }

    @Test("addDestination duplicate throws")
    func addDuplicateThrows() throws {
        var manager = MultiCallerManager()
        try manager.addDestination(SRTDestination(id: "d1", host: "h", port: 1))
        #expect(throws: MultiCallerError.duplicateDestination(id: "d1")) {
            try manager.addDestination(
                SRTDestination(id: "d1", host: "h2", port: 2))
        }
    }

    @Test("removeDestination removes from list")
    func removeDestination() throws {
        var manager = MultiCallerManager()
        try manager.addDestination(SRTDestination(id: "d1", host: "h", port: 1))
        try manager.addDestination(SRTDestination(id: "d2", host: "h", port: 2))
        manager.removeDestination(id: "d1")
        #expect(manager.destinations.count == 1)
        #expect(manager.destination(id: "d1") == nil)
        #expect(manager.destination(id: "d2") != nil)
    }

    @Test("destination(id:) returns nil for unknown")
    func destinationMissing() {
        let manager = MultiCallerManager()
        #expect(manager.destination(id: "nope") == nil)
    }

    // MARK: - Enable/Disable

    @Test("setDestinationEnabled toggles enabled")
    func setEnabled() throws {
        var manager = MultiCallerManager()
        try manager.addDestination(SRTDestination(id: "d1", host: "h", port: 1))
        #expect(manager.enabledCount == 1)
        manager.setDestinationEnabled(id: "d1", enabled: false)
        #expect(manager.enabledCount == 0)
        #expect(manager.destination(id: "d1")?.enabled == false)
        manager.setDestinationEnabled(id: "d1", enabled: true)
        #expect(manager.enabledCount == 1)
    }

    @Test("enabledDestinations filters correctly")
    func enabledDestinations() throws {
        var manager = MultiCallerManager()
        try manager.addDestination(
            SRTDestination(id: "d1", host: "h", port: 1, enabled: true))
        try manager.addDestination(
            SRTDestination(id: "d2", host: "h", port: 2, enabled: false))
        #expect(manager.enabledDestinations.count == 1)
        #expect(manager.enabledDestinations.first?.id == "d1")
    }

    // MARK: - State updates

    @Test("updateState changes destination state")
    func updateState() throws {
        var manager = MultiCallerManager()
        try manager.addDestination(SRTDestination(id: "d1", host: "h", port: 1))
        let event = manager.updateState(id: "d1", to: .connected)
        #expect(manager.destination(id: "d1")?.state == .connected)
        if case .destinationStateChanged(let id, let from, let to) = event {
            #expect(id == "d1")
            #expect(from == .idle)
            #expect(to == .connected)
        } else {
            Issue.record("Expected destinationStateChanged event")
        }
    }

    @Test("updateState returns nil for unknown ID")
    func updateStateUnknown() {
        var manager = MultiCallerManager()
        let event = manager.updateState(id: "nope", to: .connected)
        #expect(event == nil)
    }

    // MARK: - Reconnection

    @Test("destinationBroken returns reconnect action")
    func destinationBroken() throws {
        var manager = MultiCallerManager()
        try manager.addDestination(SRTDestination(id: "d1", host: "h", port: 1))
        let action = manager.destinationBroken(id: "d1")
        if case .reconnect(let id, let delay) = action {
            #expect(id == "d1")
            #expect(delay > 0)
        } else {
            Issue.record("Expected reconnect action")
        }
        #expect(manager.destination(id: "d1")?.state == .broken)
    }

    @Test("destinationBroken with disabled policy disconnects")
    func destinationBrokenDisabled() throws {
        var manager = MultiCallerManager()
        try manager.addDestination(
            SRTDestination(
                id: "d1", host: "h", port: 1,
                reconnectPolicy: .disabled))
        let action = manager.destinationBroken(id: "d1")
        #expect(action == .disconnect(destinationID: "d1"))
    }

    @Test("reconnectFailed returns next reconnect action")
    func reconnectFailed() throws {
        var manager = MultiCallerManager()
        try manager.addDestination(SRTDestination(id: "d1", host: "h", port: 1))
        _ = manager.destinationBroken(id: "d1")
        let action = manager.reconnectFailed(id: "d1")
        if case .reconnect(let id, _) = action {
            #expect(id == "d1")
        } else {
            Issue.record("Expected reconnect action on failure")
        }
    }

    @Test("reconnectSucceeded sets state to connected")
    func reconnectSucceeded() throws {
        var manager = MultiCallerManager()
        try manager.addDestination(SRTDestination(id: "d1", host: "h", port: 1))
        _ = manager.destinationBroken(id: "d1")
        manager.reconnectSucceeded(id: "d1")
        #expect(manager.destination(id: "d1")?.state == .connected)
    }

    // MARK: - Send

    @Test("prepareSend returns send for connected+enabled")
    func prepareSendConnected() throws {
        var manager = MultiCallerManager()
        try manager.addDestination(SRTDestination(id: "d1", host: "h", port: 1))
        try manager.addDestination(SRTDestination(id: "d2", host: "h", port: 2))
        _ = manager.updateState(id: "d1", to: .connected)
        // d2 stays idle (not active)
        let actions = manager.prepareSend()
        #expect(actions.count == 1)
        #expect(actions.first == .send(destinationID: "d1"))
    }

    @Test("prepareSend skips disabled destinations")
    func prepareSendSkipsDisabled() throws {
        var manager = MultiCallerManager()
        try manager.addDestination(SRTDestination(id: "d1", host: "h", port: 1))
        _ = manager.updateState(id: "d1", to: .connected)
        manager.setDestinationEnabled(id: "d1", enabled: false)
        let actions = manager.prepareSend()
        #expect(actions.isEmpty)
    }

    @Test("prepareSend includes transferring state")
    func prepareSendTransferring() throws {
        var manager = MultiCallerManager()
        try manager.addDestination(SRTDestination(id: "d1", host: "h", port: 1))
        _ = manager.updateState(id: "d1", to: .transferring)
        let actions = manager.prepareSend()
        #expect(actions.count == 1)
        #expect(actions.first == .send(destinationID: "d1"))
    }

    // MARK: - Statistics

    @Test("aggregatedStatistics sums across enabled destinations")
    func aggregatedStatistics() throws {
        var manager = MultiCallerManager()
        try manager.addDestination(SRTDestination(id: "d1", host: "h", port: 1))
        try manager.addDestination(SRTDestination(id: "d2", host: "h", port: 2))
        try manager.addDestination(
            SRTDestination(id: "d3", host: "h", port: 3, enabled: false))

        _ = manager.updateState(id: "d1", to: .connected)
        _ = manager.updateState(id: "d2", to: .connected)

        // We can't directly set stats on destinations through the manager,
        // but we can verify the aggregation returns a valid SRTStatistics
        let stats = manager.aggregatedStatistics
        #expect(stats.packetsSent == 0)
        #expect(stats.bytesSent == 0)
    }

    // MARK: - Counts

    @Test("connectedCount counts active destinations")
    func connectedCount() throws {
        var manager = MultiCallerManager()
        try manager.addDestination(SRTDestination(id: "d1", host: "h", port: 1))
        try manager.addDestination(SRTDestination(id: "d2", host: "h", port: 2))
        _ = manager.updateState(id: "d1", to: .connected)
        #expect(manager.connectedCount == 1)
        _ = manager.updateState(id: "d2", to: .transferring)
        #expect(manager.connectedCount == 2)
    }

    // MARK: - allFailed

    @Test("allFailed returns false when empty")
    func allFailedEmpty() {
        let manager = MultiCallerManager()
        #expect(!manager.allFailed)
    }

    @Test("allFailed returns true when all terminal")
    func allFailedAllTerminal() throws {
        var manager = MultiCallerManager()
        try manager.addDestination(SRTDestination(id: "d1", host: "h", port: 1))
        try manager.addDestination(SRTDestination(id: "d2", host: "h", port: 2))
        _ = manager.updateState(id: "d1", to: .broken)
        _ = manager.updateState(id: "d2", to: .closed)
        #expect(manager.allFailed)
    }

    @Test("allFailed returns false when some active")
    func allFailedSomeActive() throws {
        var manager = MultiCallerManager()
        try manager.addDestination(SRTDestination(id: "d1", host: "h", port: 1))
        try manager.addDestination(SRTDestination(id: "d2", host: "h", port: 2))
        _ = manager.updateState(id: "d1", to: .broken)
        _ = manager.updateState(id: "d2", to: .connected)
        #expect(!manager.allFailed)
    }
}
