// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTDestination Tests")
struct SRTDestinationTests {
    @Test("Default init values")
    func defaultInit() {
        let dest = SRTDestination(id: "d1", host: "192.168.1.1", port: 9000)
        #expect(dest.id == "d1")
        #expect(dest.host == "192.168.1.1")
        #expect(dest.port == 9000)
        #expect(dest.state == .idle)
        #expect(dest.statistics == SRTStatistics())
        #expect(dest.reconnectPolicy == .default)
        #expect(dest.streamID == nil)
        #expect(dest.weight == 1)
        #expect(dest.enabled)
    }

    @Test("Custom init sets all fields")
    func customInit() {
        let policy = SRTReconnectPolicy.aggressive
        let dest = SRTDestination(
            id: "backup",
            host: "10.0.0.1",
            port: 4200,
            reconnectPolicy: policy,
            streamID: "live/feed",
            weight: 5,
            enabled: false
        )
        #expect(dest.id == "backup")
        #expect(dest.host == "10.0.0.1")
        #expect(dest.port == 4200)
        #expect(dest.reconnectPolicy == policy)
        #expect(dest.streamID == "live/feed")
        #expect(dest.weight == 5)
        #expect(!dest.enabled)
    }

    @Test("Identifiable conformance uses id")
    func identifiable() {
        let dest = SRTDestination(id: "abc", host: "h", port: 1)
        #expect(dest.id == "abc")
    }

    @Test("Equatable: same values are equal")
    func equatable() {
        let a = SRTDestination(id: "x", host: "h", port: 1)
        let b = SRTDestination(id: "x", host: "h", port: 1)
        #expect(a == b)
    }

    @Test("Mutable state and statistics")
    func mutableFields() {
        var dest = SRTDestination(id: "m", host: "h", port: 1)
        dest.state = .connected
        dest.enabled = false
        dest.statistics.packetsSent = 100
        #expect(dest.state == .connected)
        #expect(!dest.enabled)
        #expect(dest.statistics.packetsSent == 100)
    }
}
