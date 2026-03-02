// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("KeyRotation Tests")
struct KeyRotationTests {
    // MARK: - Basic lifecycle

    @Test("Initial active key is even")
    func initialEven() {
        let rotation = KeyRotation()
        #expect(rotation.activeKeyIndex == .even)
    }

    @Test("setKey and key(for:) stores and retrieves")
    func setAndGet() {
        var rotation = KeyRotation()
        let evenKey: [UInt8] = [1, 2, 3]
        let oddKey: [UInt8] = [4, 5, 6]
        rotation.setKey(evenKey, for: .even)
        rotation.setKey(oddKey, for: .odd)
        #expect(rotation.key(for: .even) == evenKey)
        #expect(rotation.key(for: .odd) == oddKey)
    }

    @Test("activeKey returns active slot's key")
    func activeKey() {
        var rotation = KeyRotation()
        let key: [UInt8] = [0xAB, 0xCD]
        rotation.setKey(key, for: .even)
        #expect(rotation.activeKey == key)
    }

    @Test("activeKey returns nil when not set")
    func activeKeyNil() {
        let rotation = KeyRotation()
        #expect(rotation.activeKey == nil)
    }

    // MARK: - Rotation triggers

    @Test("packetSent returns none for most packets")
    func packetSentNone() {
        var rotation = KeyRotation(configuration: .init(refreshRate: 100, preAnnounce: 10))
        for _ in 0..<89 {
            let action = rotation.packetSent()
            #expect(action == .none)
        }
    }

    @Test("At refreshRate - preAnnounce → preAnnounce")
    func preAnnounceTriggered() {
        var rotation = KeyRotation(configuration: .init(refreshRate: 100, preAnnounce: 10))
        // Send 89 packets (none), 90th triggers preAnnounce
        for _ in 0..<89 {
            _ = rotation.packetSent()
        }
        let action = rotation.packetSent()
        #expect(action == .preAnnounce(nextKeyIndex: .odd))
    }

    @Test("At refreshRate → switchKey")
    func switchKeyTriggered() {
        var rotation = KeyRotation(configuration: .init(refreshRate: 100, preAnnounce: 10))
        for _ in 0..<99 {
            _ = rotation.packetSent()
        }
        let action = rotation.packetSent()
        #expect(action == .switchKey(newKeyIndex: .odd))
    }

    @Test("preAnnounceSent tracks state")
    func preAnnounceSent() {
        var rotation = KeyRotation(configuration: .init(refreshRate: 100, preAnnounce: 10))
        #expect(!rotation.preAnnounceSent)
        for _ in 0..<90 {
            _ = rotation.packetSent()
        }
        #expect(rotation.preAnnounceSent)
    }

    @Test("packetsSinceRotation tracks correctly")
    func packetsSinceRotation() {
        var rotation = KeyRotation()
        #expect(rotation.packetsSinceRotation == 0)
        _ = rotation.packetSent()
        #expect(rotation.packetsSinceRotation == 1)
        _ = rotation.packetSent()
        #expect(rotation.packetsSinceRotation == 2)
    }

    // MARK: - Even↔Odd cycling

    @Test("Full even → odd rotation cycle")
    func evenToOdd() {
        var rotation = KeyRotation(configuration: .init(refreshRate: 10, preAnnounce: 2))

        // Send 8 packets (threshold for preAnnounce at 10-2=8)
        for _ in 0..<7 {
            _ = rotation.packetSent()
        }
        let preAnnounce = rotation.packetSent()
        #expect(preAnnounce == .preAnnounce(nextKeyIndex: .odd))

        // Send 2 more to reach refreshRate
        _ = rotation.packetSent()
        let switchAction = rotation.packetSent()
        #expect(switchAction == .switchKey(newKeyIndex: .odd))

        rotation.completeRotation()
        #expect(rotation.activeKeyIndex == .odd)
        #expect(rotation.packetsSinceRotation == 0)
        #expect(!rotation.preAnnounceSent)
    }

    @Test("Full odd → even rotation cycle")
    func oddToEven() {
        var rotation = KeyRotation(
            configuration: .init(refreshRate: 10, preAnnounce: 2),
            initialKeyIndex: .odd
        )

        for _ in 0..<7 {
            _ = rotation.packetSent()
        }
        let preAnnounce = rotation.packetSent()
        #expect(preAnnounce == .preAnnounce(nextKeyIndex: .even))

        _ = rotation.packetSent()
        let switchAction = rotation.packetSent()
        #expect(switchAction == .switchKey(newKeyIndex: .even))

        rotation.completeRotation()
        #expect(rotation.activeKeyIndex == .even)
    }

    @Test("Double rotation: even → odd → even")
    func doubleRotation() {
        var rotation = KeyRotation(configuration: .init(refreshRate: 5, preAnnounce: 1))

        // First cycle: even → odd
        for _ in 0..<5 {
            _ = rotation.packetSent()
        }
        rotation.completeRotation()
        #expect(rotation.activeKeyIndex == .odd)

        // Second cycle: odd → even
        for _ in 0..<5 {
            _ = rotation.packetSent()
        }
        rotation.completeRotation()
        #expect(rotation.activeKeyIndex == .even)
    }

    // MARK: - KeyIndex

    @Test("KeyIndex.other returns opposite")
    func keyIndexOther() {
        #expect(KeyRotation.KeyIndex.even.other == .odd)
        #expect(KeyRotation.KeyIndex.odd.other == .even)
    }

    @Test("KeyIndex raw values match KK field")
    func keyIndexRawValues() {
        #expect(KeyRotation.KeyIndex.even.rawValue == 1)
        #expect(KeyRotation.KeyIndex.odd.rawValue == 2)
    }
}
