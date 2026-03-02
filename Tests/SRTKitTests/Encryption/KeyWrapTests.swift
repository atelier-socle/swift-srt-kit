// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("KeyWrap Tests")
struct KeyWrapTests {
    // MARK: - RFC 3394 test vectors

    @Test("RFC 3394: 128-bit KEK, 128-bit data → exact ciphertext")
    func rfc3394Test1Wrap() throws {
        let kek: [UInt8] = [
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
            0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F
        ]
        let plaintext: [UInt8] = [
            0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
            0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF
        ]
        let expectedCiphertext: [UInt8] = [
            0x1F, 0xA6, 0x8B, 0x0A, 0x81, 0x12, 0xB4, 0x47,
            0xAE, 0xF3, 0x4B, 0xD8, 0xFB, 0x5A, 0x7B, 0x82,
            0x9D, 0x3E, 0x86, 0x23, 0x71, 0xD2, 0xCF, 0xE5
        ]
        let wrapped = try KeyWrap.wrap(key: plaintext, withKEK: kek)
        #expect(wrapped == expectedCiphertext)
    }

    @Test("RFC 3394: 128-bit KEK, 128-bit data → unwrap matches plaintext")
    func rfc3394Test1Unwrap() throws {
        let kek: [UInt8] = [
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
            0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F
        ]
        let ciphertext: [UInt8] = [
            0x1F, 0xA6, 0x8B, 0x0A, 0x81, 0x12, 0xB4, 0x47,
            0xAE, 0xF3, 0x4B, 0xD8, 0xFB, 0x5A, 0x7B, 0x82,
            0x9D, 0x3E, 0x86, 0x23, 0x71, 0xD2, 0xCF, 0xE5
        ]
        let expectedPlaintext: [UInt8] = [
            0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
            0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF
        ]
        let unwrapped = try KeyWrap.unwrap(wrappedKey: ciphertext, withKEK: kek)
        #expect(unwrapped == expectedPlaintext)
    }

    @Test("RFC 3394: 256-bit KEK, 256-bit data → exact ciphertext")
    func rfc3394Test2Wrap() throws {
        let kek: [UInt8] = [
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
            0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
            0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
            0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F
        ]
        let plaintext: [UInt8] = [
            0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
            0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF,
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
            0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F
        ]
        let expectedCiphertext: [UInt8] = [
            0x28, 0xC9, 0xF4, 0x04, 0xC4, 0xB8, 0x10, 0xF4,
            0xCB, 0xCC, 0xB3, 0x5C, 0xFB, 0x87, 0xF8, 0x26,
            0x3F, 0x57, 0x86, 0xE2, 0xD8, 0x0E, 0xD3, 0x26,
            0xCB, 0xC7, 0xF0, 0xE7, 0x1A, 0x99, 0xF4, 0x3B,
            0xFB, 0x98, 0x8B, 0x9B, 0x7A, 0x02, 0xDD, 0x21
        ]
        let wrapped = try KeyWrap.wrap(key: plaintext, withKEK: kek)
        #expect(wrapped == expectedCiphertext)
    }

    @Test("RFC 3394: 256-bit KEK, 256-bit data → unwrap matches")
    func rfc3394Test2Unwrap() throws {
        let kek: [UInt8] = [
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
            0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
            0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
            0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F
        ]
        let ciphertext: [UInt8] = [
            0x28, 0xC9, 0xF4, 0x04, 0xC4, 0xB8, 0x10, 0xF4,
            0xCB, 0xCC, 0xB3, 0x5C, 0xFB, 0x87, 0xF8, 0x26,
            0x3F, 0x57, 0x86, 0xE2, 0xD8, 0x0E, 0xD3, 0x26,
            0xCB, 0xC7, 0xF0, 0xE7, 0x1A, 0x99, 0xF4, 0x3B,
            0xFB, 0x98, 0x8B, 0x9B, 0x7A, 0x02, 0xDD, 0x21
        ]
        let expectedPlaintext: [UInt8] = [
            0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
            0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF,
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
            0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F
        ]
        let unwrapped = try KeyWrap.unwrap(wrappedKey: ciphertext, withKEK: kek)
        #expect(unwrapped == expectedPlaintext)
    }

    // MARK: - Roundtrip

    @Test("Wrap then unwrap roundtrip AES-128")
    func roundtripAES128() throws {
        let kek = [UInt8](repeating: 0x42, count: 16)
        let sek = [UInt8](repeating: 0xAB, count: 16)
        let wrapped = try KeyWrap.wrap(key: sek, withKEK: kek)
        let unwrapped = try KeyWrap.unwrap(wrappedKey: wrapped, withKEK: kek)
        #expect(unwrapped == sek)
    }

    @Test("Wrap then unwrap roundtrip AES-192")
    func roundtripAES192() throws {
        let kek = [UInt8](repeating: 0x42, count: 24)
        let sek = [UInt8](repeating: 0xCD, count: 24)
        let wrapped = try KeyWrap.wrap(key: sek, withKEK: kek)
        let unwrapped = try KeyWrap.unwrap(wrappedKey: wrapped, withKEK: kek)
        #expect(unwrapped == sek)
    }

    @Test("Wrap then unwrap roundtrip AES-256")
    func roundtripAES256() throws {
        let kek = [UInt8](repeating: 0x42, count: 32)
        let sek = [UInt8](repeating: 0xEF, count: 32)
        let wrapped = try KeyWrap.wrap(key: sek, withKEK: kek)
        let unwrapped = try KeyWrap.unwrap(wrappedKey: wrapped, withKEK: kek)
        #expect(unwrapped == sek)
    }

    @Test("Wrapped output is 8 bytes longer than input")
    func wrappedLength() throws {
        let kek = [UInt8](repeating: 0x42, count: 16)
        let sek = [UInt8](repeating: 0xAB, count: 16)
        let wrapped = try KeyWrap.wrap(key: sek, withKEK: kek)
        #expect(wrapped.count == sek.count + 8)
    }

    // MARK: - Error cases

    @Test("Unwrap with wrong KEK fails with integrity error")
    func wrongKEK() throws {
        let kek1 = [UInt8](repeating: 0x42, count: 16)
        let kek2 = [UInt8](repeating: 0x43, count: 16)
        let sek = [UInt8](repeating: 0xAB, count: 16)
        let wrapped = try KeyWrap.wrap(key: sek, withKEK: kek1)
        #expect(throws: SRTEncryptionError.keyWrapIntegrityFailure) {
            try KeyWrap.unwrap(wrappedKey: wrapped, withKEK: kek2)
        }
    }

    @Test("Unwrap corrupted ciphertext fails with integrity error")
    func corruptedCiphertext() throws {
        let kek = [UInt8](repeating: 0x42, count: 16)
        let sek = [UInt8](repeating: 0xAB, count: 16)
        var wrapped = try KeyWrap.wrap(key: sek, withKEK: kek)
        wrapped[10] ^= 0xFF  // Corrupt a byte
        #expect(throws: SRTEncryptionError.keyWrapIntegrityFailure) {
            try KeyWrap.unwrap(wrappedKey: wrapped, withKEK: kek)
        }
    }

    @Test("Key data not multiple of 8 bytes throws error")
    func invalidKeyLength() {
        let kek = [UInt8](repeating: 0x42, count: 16)
        let sek = [UInt8](repeating: 0xAB, count: 15)  // Not multiple of 8
        #expect(throws: SRTEncryptionError.invalidKeyDataLength(got: 15)) {
            try KeyWrap.wrap(key: sek, withKEK: kek)
        }
    }

    @Test("Empty key data throws error")
    func emptyKey() {
        let kek = [UInt8](repeating: 0x42, count: 16)
        #expect(throws: SRTEncryptionError.invalidKeyDataLength(got: 0)) {
            try KeyWrap.wrap(key: [], withKEK: kek)
        }
    }
}
