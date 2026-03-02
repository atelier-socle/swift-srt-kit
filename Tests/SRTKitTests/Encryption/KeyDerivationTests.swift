// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("KeyDerivation Tests")
struct KeyDerivationTests {
    // MARK: - PBKDF2 RFC 6070 test vectors

    @Test("Different iteration counts produce different keys")
    func differentIterations() throws {
        let salt = [UInt8](repeating: 0xAB, count: 16)
        let key1 = try KeyDerivation.deriveKEK(
            passphrase: "testsecretphrase",
            salt: salt,
            keySize: .aes128,
            iterations: 1
        )
        let key2 = try KeyDerivation.deriveKEK(
            passphrase: "testsecretphrase",
            salt: salt,
            keySize: .aes128,
            iterations: 2048
        )
        #expect(key1 != key2)
    }

    @Test("Derive AES-128 key produces 16 bytes")
    func deriveAES128() throws {
        let salt = [UInt8](repeating: 0xAB, count: 16)
        let key = try KeyDerivation.deriveKEK(
            passphrase: "testsecretphrase",
            salt: salt,
            keySize: .aes128
        )
        #expect(key.count == 16)
    }

    @Test("Derive AES-192 key produces 24 bytes")
    func deriveAES192() throws {
        let salt = [UInt8](repeating: 0xAB, count: 16)
        let key = try KeyDerivation.deriveKEK(
            passphrase: "testsecretphrase",
            salt: salt,
            keySize: .aes192
        )
        #expect(key.count == 24)
    }

    @Test("Derive AES-256 key produces 32 bytes")
    func deriveAES256() throws {
        let salt = [UInt8](repeating: 0xAB, count: 16)
        let key = try KeyDerivation.deriveKEK(
            passphrase: "testsecretphrase",
            salt: salt,
            keySize: .aes256
        )
        #expect(key.count == 32)
    }

    @Test("Same inputs produce same output (deterministic)")
    func deterministic() throws {
        let salt = [UInt8](repeating: 0xCD, count: 16)
        let key1 = try KeyDerivation.deriveKEK(
            passphrase: "mysecretpassword",
            salt: salt,
            keySize: .aes128
        )
        let key2 = try KeyDerivation.deriveKEK(
            passphrase: "mysecretpassword",
            salt: salt,
            keySize: .aes128
        )
        #expect(key1 == key2)
    }

    @Test("Different salt produces different output")
    func differentSalt() throws {
        let salt1 = [UInt8](repeating: 0x01, count: 16)
        let salt2 = [UInt8](repeating: 0x02, count: 16)
        let key1 = try KeyDerivation.deriveKEK(
            passphrase: "mysecretpassword",
            salt: salt1,
            keySize: .aes128
        )
        let key2 = try KeyDerivation.deriveKEK(
            passphrase: "mysecretpassword",
            salt: salt2,
            keySize: .aes128
        )
        #expect(key1 != key2)
    }

    @Test("Different passphrase produces different output")
    func differentPassphrase() throws {
        let salt = [UInt8](repeating: 0xAB, count: 16)
        let key1 = try KeyDerivation.deriveKEK(
            passphrase: "mysecretpassword1",
            salt: salt,
            keySize: .aes128
        )
        let key2 = try KeyDerivation.deriveKEK(
            passphrase: "mysecretpassword2",
            salt: salt,
            keySize: .aes128
        )
        #expect(key1 != key2)
    }

    // MARK: - Salt generation

    @Test("generateSalt returns 16 bytes")
    func saltSize() {
        let salt = KeyDerivation.generateSalt()
        #expect(salt.count == 16)
    }

    @Test("Two salt generations differ")
    func saltsDiffer() {
        let salt1 = KeyDerivation.generateSalt()
        let salt2 = KeyDerivation.generateSalt()
        #expect(salt1 != salt2)
    }

    // MARK: - Validation

    @Test("Passphrase 9 chars throws passphraseTooShort")
    func tooShort() {
        #expect(throws: SRTEncryptionError.passphraseTooShort(length: 9)) {
            try KeyDerivation.validatePassphrase("123456789")
        }
    }

    @Test("Passphrase 10 chars is OK")
    func minLength() throws {
        try KeyDerivation.validatePassphrase("1234567890")
    }

    @Test("Passphrase 79 chars is OK")
    func maxLength() throws {
        let phrase = String(repeating: "a", count: 79)
        try KeyDerivation.validatePassphrase(phrase)
    }

    @Test("Passphrase 80 chars throws passphraseTooLong")
    func tooLong() {
        let phrase = String(repeating: "a", count: 80)
        #expect(throws: SRTEncryptionError.passphraseTooLong(length: 80)) {
            try KeyDerivation.validatePassphrase(phrase)
        }
    }

    @Test("Invalid salt size throws error")
    func invalidSaltSize() {
        #expect(throws: SRTEncryptionError.invalidSaltSize(got: 8)) {
            try KeyDerivation.deriveKEK(
                passphrase: "mysecretpassword",
                salt: [UInt8](repeating: 0, count: 8),
                keySize: .aes128
            )
        }
    }
}
