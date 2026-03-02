// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SocketIDGenerator Tests")
struct SocketIDGeneratorTests {
    @Test("generate() produces non-zero value")
    func generateNonZero() {
        let id = SocketIDGenerator.generate()
        #expect(id != 0)
    }

    @Test("generate() produces different values on successive calls")
    func generateDifferentValues() {
        var ids = Set<UInt32>()
        for _ in 0..<100 {
            ids.insert(SocketIDGenerator.generate())
        }
        // With 100 random UInt32 values, expect near-unique set
        #expect(ids.count >= 95)
    }

    @Test("generate() never produces 0 in 1000 calls")
    func generateNeverZero() {
        for _ in 0..<1000 {
            #expect(SocketIDGenerator.generate() != 0)
        }
    }

    @Test("generate() values are in valid UInt32 range")
    func generateValidRange() {
        for _ in 0..<100 {
            let id = SocketIDGenerator.generate()
            #expect(id >= 1)
            #expect(id <= UInt32.max)
        }
    }

    @Test("generate(avoiding:) avoids specified IDs")
    func generateAvoidingIDs() {
        let existing: Set<UInt32> = [1, 2, 3, 4, 5]
        for _ in 0..<100 {
            let id = SocketIDGenerator.generate(avoiding: existing)
            #expect(!existing.contains(id))
        }
    }

    @Test("generate(avoiding:) with empty set works normally")
    func generateAvoidingEmpty() {
        let id = SocketIDGenerator.generate(avoiding: [])
        #expect(id != 0)
    }

    @Test("generate(avoiding:) with nearly-full set still finds a value")
    func generateAvoidingNearlyFull() {
        // Create a set with a few hundred values
        var existing = Set<UInt32>()
        for i: UInt32 in 1...500 {
            existing.insert(i)
        }
        let id = SocketIDGenerator.generate(avoiding: existing)
        #expect(!existing.contains(id))
        #expect(id != 0)
    }

    @Test("generate(avoiding:) result is non-zero")
    func generateAvoidingNonZero() {
        let id = SocketIDGenerator.generate(avoiding: [1, 2, 3])
        #expect(id != 0)
    }
}
