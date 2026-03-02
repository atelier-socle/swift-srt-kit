// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("PacketDeduplicator Tests")
struct PacketDeduplicatorTests {
    @Test("New sequence returns isNew true")
    func newSequenceIsNew() {
        var dedup = PacketDeduplicator()
        let result = dedup.isNew(SequenceNumber(0))
        #expect(result)
    }

    @Test("Same sequence again returns isNew false")
    func sameSequenceNotNew() {
        var dedup = PacketDeduplicator()
        _ = dedup.isNew(SequenceNumber(0))
        let result = dedup.isNew(SequenceNumber(0))
        #expect(!result)
    }

    @Test("Different sequence returns isNew true")
    func differentSequenceIsNew() {
        var dedup = PacketDeduplicator()
        _ = dedup.isNew(SequenceNumber(0))
        let result = dedup.isNew(SequenceNumber(1))
        #expect(result)
    }

    @Test("duplicatesDetected counter increments")
    func duplicatesDetectedIncrements() {
        var dedup = PacketDeduplicator()
        #expect(dedup.duplicatesDetected == 0)
        _ = dedup.isNew(SequenceNumber(0))
        _ = dedup.isNew(SequenceNumber(0))
        #expect(dedup.duplicatesDetected == 1)
        _ = dedup.isNew(SequenceNumber(0))
        #expect(dedup.duplicatesDetected == 2)
    }

    @Test("reset clears state")
    func resetClearsState() {
        var dedup = PacketDeduplicator()
        _ = dedup.isNew(SequenceNumber(0))
        _ = dedup.isNew(SequenceNumber(0))
        dedup.reset()
        #expect(dedup.duplicatesDetected == 0)
    }

    @Test("After reset, same sequence is new")
    func afterResetSameIsNew() {
        var dedup = PacketDeduplicator()
        _ = dedup.isNew(SequenceNumber(0))
        dedup.reset()
        let result = dedup.isNew(SequenceNumber(0))
        #expect(result)
    }

    @Test("Large window handles many sequences")
    func largeWindowManySequences() {
        var dedup = PacketDeduplicator(windowSize: 8192)
        for i: UInt32 in 0..<1000 {
            let result = dedup.isNew(SequenceNumber(i))
            #expect(result)
        }
        #expect(dedup.duplicatesDetected == 0)
    }

    @Test("Custom window size applied")
    func customWindowSize() {
        let dedup = PacketDeduplicator(windowSize: 256)
        #expect(dedup.windowSize == 256)
    }
}
