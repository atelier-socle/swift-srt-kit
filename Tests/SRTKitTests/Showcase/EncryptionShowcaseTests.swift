// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("Encryption Showcase")
struct EncryptionShowcaseTests {
    // MARK: - Encrypt / Decrypt Roundtrip

    @Test("AES-CTR encrypt then decrypt roundtrip")
    func aesCTRRoundtrip() throws {
        let sek = Array(repeating: UInt8(0x42), count: 16)
        let salt = Array(repeating: UInt8(0x01), count: 16)

        let encryptor = try SRTEncryptor(
            sek: sek, salt: salt,
            cipherMode: .ctr, keySize: .aes128)
        let decryptor = try SRTDecryptor(
            sek: sek, salt: salt,
            cipherMode: .ctr, keySize: .aes128)

        let plaintext: [UInt8] = Array(0..<188)
        let header: [UInt8] = [0x00, 0x00, 0x00, 0x2A]
        let encrypted = try encryptor.encrypt(
            payload: plaintext,
            sequenceNumber: SequenceNumber(42),
            header: header)
        #expect(encrypted != plaintext)

        let decrypted = try decryptor.decrypt(
            payload: encrypted,
            sequenceNumber: SequenceNumber(42),
            header: header)
        #expect(decrypted == plaintext)
    }

    @Test("AES-GCM encrypt then decrypt roundtrip")
    func aesGCMRoundtrip() throws {
        let sek = Array(repeating: UInt8(0x55), count: 32)
        let salt = Array(repeating: UInt8(0x02), count: 16)

        let encryptor = try SRTEncryptor(
            sek: sek, salt: salt,
            cipherMode: .gcm, keySize: .aes256)
        let decryptor = try SRTDecryptor(
            sek: sek, salt: salt,
            cipherMode: .gcm, keySize: .aes256)

        let plaintext: [UInt8] = (0..<1316).map { UInt8($0 % 256) }
        let header: [UInt8] = [0x00, 0x00, 0x00, 0x01]
        let encrypted = try encryptor.encrypt(
            payload: plaintext,
            sequenceNumber: SequenceNumber(1),
            header: header)
        // GCM adds 16-byte auth tag
        #expect(encrypted.count == plaintext.count + CipherMode.gcmTagSize)

        let decrypted = try decryptor.decrypt(
            payload: encrypted,
            sequenceNumber: SequenceNumber(1),
            header: header)
        #expect(decrypted == plaintext)
    }

    // MARK: - Key Derivation

    @Test("KeyDerivation derives KEK from passphrase")
    func deriveKEK() throws {
        let passphrase = "test-passphrase-1234"
        let salt = KeyDerivation.generateSalt()
        #expect(salt.count == KeyDerivation.saltSize)

        let kek = try KeyDerivation.deriveKEK(
            passphrase: passphrase,
            salt: salt,
            keySize: .aes128)
        #expect(kek.count == KeySize.aes128.rawValue)

        // Same inputs → same output
        let kek2 = try KeyDerivation.deriveKEK(
            passphrase: passphrase,
            salt: salt,
            keySize: .aes128)
        #expect(kek == kek2)
    }

    @Test("KeyDerivation passphrase validation")
    func passphraseValidation() {
        // Too short
        #expect(throws: (any Error).self) {
            try KeyDerivation.validatePassphrase("short")
        }
        // Valid length (10-79)
        #expect(throws: Never.self) {
            try KeyDerivation.validatePassphrase(
                "valid-pass-1234")
        }
    }

    // MARK: - Key Wrap

    @Test("KeyWrap wrap then unwrap roundtrip")
    func keyWrapRoundtrip() throws {
        let key = Array(repeating: UInt8(0xAA), count: 16)
        let kek = Array(repeating: UInt8(0xBB), count: 16)

        let wrapped = try KeyWrap.wrap(key: key, withKEK: kek)
        #expect(wrapped.count == key.count + 8)

        let unwrapped = try KeyWrap.unwrap(
            wrappedKey: wrapped, withKEK: kek)
        #expect(unwrapped == key)
    }

    // MARK: - Key Rotation

    @Test("KeyRotation pre-announce and switch lifecycle")
    func keyRotationLifecycle() {
        var rotation = KeyRotation(
            configuration: .init(
                refreshRate: 10,
                preAnnounce: 3),
            initialKeyIndex: .even)
        #expect(rotation.activeKeyIndex == .even)

        // Send packets until pre-announce
        var preAnnounced = false
        var switched = false
        for _ in 0..<15 {
            let action = rotation.packetSent()
            switch action {
            case .preAnnounce:
                preAnnounced = true
            case .switchKey:
                switched = true
            case .none:
                break
            }
        }
        #expect(preAnnounced)
        #expect(switched)
    }

    @Test("KeyIndex toggles between even and odd")
    func keyIndexToggle() {
        let even = KeyRotation.KeyIndex.even
        let odd = KeyRotation.KeyIndex.odd
        #expect(even.other == .odd)
        #expect(odd.other == .even)
    }

    // MARK: - Cipher Mode & Key Size

    @Test("CipherMode descriptions")
    func cipherModeDescriptions() {
        #expect(CipherMode.ctr.description == "AES-CTR")
        #expect(CipherMode.gcm.description == "AES-GCM")
        #expect(CipherMode.gcmTagSize == 16)
    }

    @Test("KeySize variants and handshake values")
    func keySizeVariants() {
        #expect(KeySize.aes128.rawValue == 16)
        #expect(KeySize.aes192.rawValue == 24)
        #expect(KeySize.aes256.rawValue == 32)

        // Wrapped size = key + 8
        #expect(KeySize.aes128.wrappedSize == 24)

        // Handshake encoding roundtrip
        for keySize in KeySize.allCases {
            let decoded = KeySize(handshakeValue: keySize.handshakeValue)
            #expect(decoded == keySize)
        }
    }
}
