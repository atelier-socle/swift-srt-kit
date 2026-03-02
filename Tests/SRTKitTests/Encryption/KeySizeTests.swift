// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("KeySize Tests")
struct KeySizeTests {
    @Test("AES-128 rawValue is 16")
    func aes128RawValue() {
        #expect(KeySize.aes128.rawValue == 16)
    }

    @Test("AES-192 rawValue is 24")
    func aes192RawValue() {
        #expect(KeySize.aes192.rawValue == 24)
    }

    @Test("AES-256 rawValue is 32")
    func aes256RawValue() {
        #expect(KeySize.aes256.rawValue == 32)
    }

    @Test("wrappedSize is rawValue + 8")
    func wrappedSize() {
        #expect(KeySize.aes128.wrappedSize == 24)
        #expect(KeySize.aes192.wrappedSize == 32)
        #expect(KeySize.aes256.wrappedSize == 40)
    }

    @Test("handshakeValue roundtrip")
    func handshakeRoundtrip() {
        for size in KeySize.allCases {
            let restored = KeySize(handshakeValue: size.handshakeValue)
            #expect(restored == size)
        }
    }

    @Test("Invalid handshake value returns nil")
    func invalidHandshakeValue() {
        #expect(KeySize(handshakeValue: 0) == nil)
        #expect(KeySize(handshakeValue: 1) == nil)
        #expect(KeySize(handshakeValue: 5) == nil)
    }

    @Test("CaseIterable lists all three")
    func allCases() {
        #expect(KeySize.allCases.count == 3)
    }

    @Test("Handshake values are 2, 3, 4")
    func handshakeValues() {
        #expect(KeySize.aes128.handshakeValue == 2)
        #expect(KeySize.aes192.handshakeValue == 3)
        #expect(KeySize.aes256.handshakeValue == 4)
    }
}
