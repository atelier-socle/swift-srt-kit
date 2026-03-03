// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("Multi-Stream Showcase")
struct MultiStreamShowcaseTests {
    @Test("MultiStreamManager add and route streams")
    func multiStreamRouting() throws {
        var manager = MultiStreamManager()

        // Add streams
        try manager.addStream(
            StreamInfo(id: 1, socketID: 100, streamID: "video"))
        try manager.addStream(
            StreamInfo(id: 2, socketID: 200, streamID: "audio"))

        #expect(manager.activeCount == 2)

        // Route by destinationSocketID → returns stream ID
        let streamID = manager.routePacket(
            destinationSocketID: 100)
        #expect(streamID == 1)

        // Unknown socketID
        let unknown = manager.routePacket(
            destinationSocketID: 999)
        #expect(unknown == nil)
    }

    @Test("MultiStreamManager remove stream")
    func removeStream() throws {
        var manager = MultiStreamManager()
        try manager.addStream(
            StreamInfo(id: 1, socketID: 100, streamID: "cam1"))
        try manager.addStream(
            StreamInfo(id: 2, socketID: 200, streamID: "cam2"))

        manager.removeStream(id: 1)
        #expect(manager.activeCount == 1)

        // Lookup removed stream
        let removed = manager.stream(id: 1)
        #expect(removed == nil)
    }

    @Test("MultiStreamManager capacity enforcement")
    func capacityEnforcement() throws {
        var manager = MultiStreamManager(maxStreams: 2)
        try manager.addStream(
            StreamInfo(id: 1, socketID: 100))
        try manager.addStream(
            StreamInfo(id: 2, socketID: 200))

        #expect(throws: MultiStreamError.self) {
            try manager.addStream(
                StreamInfo(id: 3, socketID: 300))
        }
    }

    @Test("MultiStreamManager duplicate ID rejected")
    func duplicateRejected() throws {
        var manager = MultiStreamManager()
        try manager.addStream(
            StreamInfo(id: 1, socketID: 100))

        #expect(throws: MultiStreamError.self) {
            try manager.addStream(
                StreamInfo(id: 1, socketID: 200))
        }
    }
}

@Suite("Multi-Caller Showcase")
struct MultiCallerShowcaseTests {
    @Test("MultiCallerManager destination management")
    func destinationManagement() throws {
        var manager = MultiCallerManager()

        let d1 = SRTDestination(
            id: "cdn1", host: "cdn1.example.com", port: 4200)
        let d2 = SRTDestination(
            id: "cdn2", host: "cdn2.example.com", port: 4201)

        try manager.addDestination(d1)
        try manager.addDestination(d2)
        #expect(manager.destinations.count == 2)

        // Enable/disable
        manager.setDestinationEnabled(id: "cdn1", enabled: false)
        #expect(manager.enabledCount == 1)

        manager.setDestinationEnabled(id: "cdn1", enabled: true)
        #expect(manager.enabledCount == 2)
    }

    @Test("MultiCallerManager remove destination")
    func removeDestination() throws {
        var manager = MultiCallerManager()
        let d1 = SRTDestination(
            id: "cdn1", host: "cdn1.example.com", port: 4200)
        try manager.addDestination(d1)

        manager.removeDestination(id: "cdn1")
        #expect(manager.destinations.count == 0)
    }
}
