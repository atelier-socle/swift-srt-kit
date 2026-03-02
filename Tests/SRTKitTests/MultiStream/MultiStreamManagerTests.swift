// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("MultiStreamManager Tests")
struct MultiStreamManagerTests {
    // MARK: - Initialization

    @Test("Default maxStreams is 16")
    func defaultMaxStreams() {
        let manager = MultiStreamManager()
        #expect(manager.maxStreams == 16)
    }

    @Test("Custom maxStreams")
    func customMaxStreams() {
        let manager = MultiStreamManager(maxStreams: 4)
        #expect(manager.maxStreams == 4)
    }

    @Test("Initial activeCount is 0")
    func initialActiveCount() {
        let manager = MultiStreamManager()
        #expect(manager.activeCount == 0)
        #expect(manager.streams.isEmpty)
    }

    // MARK: - Add / Remove

    @Test("addStream adds to streams list")
    func addStream() throws {
        var manager = MultiStreamManager()
        let info = StreamInfo(id: 1, socketID: 100)
        try manager.addStream(info)
        #expect(manager.activeCount == 1)
        #expect(manager.streams.first == info)
    }

    @Test("addStream duplicate ID throws")
    func addDuplicateThrows() throws {
        var manager = MultiStreamManager()
        let info = StreamInfo(id: 1, socketID: 100)
        try manager.addStream(info)
        #expect(throws: MultiStreamError.duplicateStream(id: 1)) {
            try manager.addStream(StreamInfo(id: 1, socketID: 200))
        }
    }

    @Test("addStream at capacity throws")
    func addAtCapacityThrows() throws {
        var manager = MultiStreamManager(maxStreams: 2)
        try manager.addStream(StreamInfo(id: 1, socketID: 100))
        try manager.addStream(StreamInfo(id: 2, socketID: 200))
        #expect(throws: MultiStreamError.maxStreamsReached(max: 2)) {
            try manager.addStream(StreamInfo(id: 3, socketID: 300))
        }
    }

    @Test("removeStream removes from list")
    func removeStream() throws {
        var manager = MultiStreamManager()
        try manager.addStream(StreamInfo(id: 1, socketID: 100))
        try manager.addStream(StreamInfo(id: 2, socketID: 200))
        manager.removeStream(id: 1)
        #expect(manager.activeCount == 1)
        #expect(manager.stream(id: 1) == nil)
        #expect(manager.stream(id: 2) != nil)
    }

    @Test("removeStream nonexistent is no-op")
    func removeNonexistent() {
        var manager = MultiStreamManager()
        manager.removeStream(id: 999)
        #expect(manager.activeCount == 0)
    }

    // MARK: - Lookup

    @Test("stream(id:) returns matching stream")
    func streamLookup() throws {
        var manager = MultiStreamManager()
        let info = StreamInfo(
            id: 5, socketID: 500, streamID: "live", encrypted: true,
            creationTime: 1000)
        try manager.addStream(info)
        let found = manager.stream(id: 5)
        #expect(found == info)
    }

    @Test("stream(id:) returns nil for unknown")
    func streamLookupMissing() {
        let manager = MultiStreamManager()
        #expect(manager.stream(id: 42) == nil)
    }

    // MARK: - Capacity

    @Test("isFull returns true at capacity")
    func isFullAtCapacity() throws {
        var manager = MultiStreamManager(maxStreams: 1)
        #expect(!manager.isFull)
        try manager.addStream(StreamInfo(id: 1, socketID: 100))
        #expect(manager.isFull)
    }

    // MARK: - Routing

    @Test("routePacket finds stream by socketID")
    func routePacketFinds() throws {
        var manager = MultiStreamManager()
        try manager.addStream(StreamInfo(id: 10, socketID: 500))
        try manager.addStream(StreamInfo(id: 20, socketID: 600))
        let routed = manager.routePacket(destinationSocketID: 600)
        #expect(routed == 20)
    }

    @Test("routePacket returns nil for unknown socketID")
    func routePacketMissing() {
        let manager = MultiStreamManager()
        #expect(manager.routePacket(destinationSocketID: 999) == nil)
    }
}
