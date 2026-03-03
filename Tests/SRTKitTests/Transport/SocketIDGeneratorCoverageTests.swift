// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SocketIDGenerator Coverage Tests")
struct SocketIDGeneratorCoverageTests {

    @Test("generate() returns non-zero value")
    func generateReturnsNonZero() {
        let id = SocketIDGenerator.generate()
        #expect(id != 0)
    }

    @Test("generate() returns values in valid range")
    func generateReturnsValidRange() {
        for _ in 0..<100 {
            let id = SocketIDGenerator.generate()
            #expect(id >= 1)
            #expect(id <= UInt32.max)
        }
    }

    @Test("generate(avoiding:) returns ID not in existing set")
    func generateAvoidingExisting() {
        let existing: Set<UInt32> = [1, 2, 3, 4, 5]
        let id = SocketIDGenerator.generate(avoiding: existing)
        #expect(!existing.contains(id))
        #expect(id != 0)
    }

    @Test("generate(avoiding:) with empty set returns valid ID")
    func generateAvoidingEmpty() {
        let id = SocketIDGenerator.generate(avoiding: [])
        #expect(id > 0)
    }

    @Test("generate(avoiding:) with large set still finds an ID")
    func generateAvoidingLargeSet() {
        // Create a set with many IDs (but far from exhausting UInt32 space)
        var existing = Set<UInt32>()
        for i: UInt32 in 1...1000 {
            existing.insert(i)
        }
        let id = SocketIDGenerator.generate(avoiding: existing)
        #expect(!existing.contains(id))
        #expect(id != 0)
    }

    @Test("generate(avoiding:) always returns unique IDs across calls")
    func generateAvoidingAccumulatesUnique() {
        var existing = Set<UInt32>()
        for _ in 0..<50 {
            let id = SocketIDGenerator.generate(avoiding: existing)
            #expect(!existing.contains(id))
            #expect(id != 0)
            existing.insert(id)
        }
        #expect(existing.count == 50)
    }

    @Test("generate(avoiding:) with set containing zero still returns non-zero")
    func generateAvoidingSetWithZero() {
        let existing: Set<UInt32> = [0]
        let id = SocketIDGenerator.generate(avoiding: existing)
        #expect(id != 0)
    }

    @Test("generate(avoiding:) with single-element set avoids it")
    func generateAvoidingSingleElement() {
        // Run multiple times to be confident
        for value: UInt32 in [1, UInt32.max, UInt32.max / 2] {
            let existing: Set<UInt32> = [value]
            for _ in 0..<20 {
                let id = SocketIDGenerator.generate(avoiding: existing)
                #expect(id != value)
                #expect(id != 0)
            }
        }
    }
}
