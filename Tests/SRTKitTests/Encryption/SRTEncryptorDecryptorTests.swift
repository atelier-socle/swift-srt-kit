// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTEncryptor/Decryptor Tests")
struct SRTEncryptorDecryptorTests {
    private let testSalt: [UInt8] = [
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10
    ]

    private func makeKey(size: KeySize) -> [UInt8] {
        [UInt8](repeating: 0xAB, count: size.rawValue)
    }

    // MARK: - AES-CTR roundtrip

    @Test("CTR: encrypt then decrypt AES-128")
    func ctrRoundtripAES128() throws {
        let sek = makeKey(size: .aes128)
        let encryptor = try SRTEncryptor(
            sek: sek, salt: testSalt, cipherMode: .ctr, keySize: .aes128)
        let decryptor = try SRTDecryptor(
            sek: sek, salt: testSalt, cipherMode: .ctr, keySize: .aes128)

        let plaintext: [UInt8] = Array("Hello, SRT encryption!".utf8)
        let seq = SequenceNumber(42)
        let encrypted = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: seq, header: [])
        let decrypted = try decryptor.decrypt(
            payload: encrypted, sequenceNumber: seq, header: [])
        #expect(decrypted == plaintext)
    }

    @Test("CTR: encrypt then decrypt AES-192")
    func ctrRoundtripAES192() throws {
        let sek = makeKey(size: .aes192)
        let encryptor = try SRTEncryptor(
            sek: sek, salt: testSalt, cipherMode: .ctr, keySize: .aes192)
        let decryptor = try SRTDecryptor(
            sek: sek, salt: testSalt, cipherMode: .ctr, keySize: .aes192)

        let plaintext: [UInt8] = Array("AES-192 test data".utf8)
        let seq = SequenceNumber(100)
        let encrypted = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: seq, header: [])
        let decrypted = try decryptor.decrypt(
            payload: encrypted, sequenceNumber: seq, header: [])
        #expect(decrypted == plaintext)
    }

    @Test("CTR: encrypt then decrypt AES-256")
    func ctrRoundtripAES256() throws {
        let sek = makeKey(size: .aes256)
        let encryptor = try SRTEncryptor(
            sek: sek, salt: testSalt, cipherMode: .ctr, keySize: .aes256)
        let decryptor = try SRTDecryptor(
            sek: sek, salt: testSalt, cipherMode: .ctr, keySize: .aes256)

        let plaintext: [UInt8] = Array("AES-256 test data for roundtrip".utf8)
        let seq = SequenceNumber(999)
        let encrypted = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: seq, header: [])
        let decrypted = try decryptor.decrypt(
            payload: encrypted, sequenceNumber: seq, header: [])
        #expect(decrypted == plaintext)
    }

    @Test("CTR: different sequence numbers produce different ciphertext")
    func ctrDifferentSequences() throws {
        let sek = makeKey(size: .aes128)
        let encryptor = try SRTEncryptor(
            sek: sek, salt: testSalt, cipherMode: .ctr, keySize: .aes128)

        let plaintext: [UInt8] = Array("same data".utf8)
        let enc1 = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: SequenceNumber(1), header: [])
        let enc2 = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: SequenceNumber(2), header: [])
        #expect(enc1 != enc2)
    }

    @Test("CTR: same plaintext + same sequence = same ciphertext")
    func ctrDeterministic() throws {
        let sek = makeKey(size: .aes128)
        let encryptor = try SRTEncryptor(
            sek: sek, salt: testSalt, cipherMode: .ctr, keySize: .aes128)

        let plaintext: [UInt8] = Array("deterministic test".utf8)
        let seq = SequenceNumber(42)
        let enc1 = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: seq, header: [])
        let enc2 = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: seq, header: [])
        #expect(enc1 == enc2)
    }

    @Test("CTR: empty payload roundtrip")
    func ctrEmptyPayload() throws {
        let sek = makeKey(size: .aes128)
        let encryptor = try SRTEncryptor(
            sek: sek, salt: testSalt, cipherMode: .ctr, keySize: .aes128)
        let decryptor = try SRTDecryptor(
            sek: sek, salt: testSalt, cipherMode: .ctr, keySize: .aes128)

        let encrypted = try encryptor.encrypt(
            payload: [], sequenceNumber: SequenceNumber(0), header: [])
        let decrypted = try decryptor.decrypt(
            payload: encrypted, sequenceNumber: SequenceNumber(0), header: [])
        #expect(decrypted.isEmpty)
    }

    @Test("CTR: large payload roundtrip")
    func ctrLargePayload() throws {
        let sek = makeKey(size: .aes256)
        let encryptor = try SRTEncryptor(
            sek: sek, salt: testSalt, cipherMode: .ctr, keySize: .aes256)
        let decryptor = try SRTDecryptor(
            sek: sek, salt: testSalt, cipherMode: .ctr, keySize: .aes256)

        let plaintext = [UInt8](repeating: 0x42, count: 8192)
        let seq = SequenceNumber(12345)
        let encrypted = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: seq, header: [])
        let decrypted = try decryptor.decrypt(
            payload: encrypted, sequenceNumber: seq, header: [])
        #expect(decrypted == plaintext)
    }

    @Test("CTR: ciphertext same length as plaintext")
    func ctrSameLength() throws {
        let sek = makeKey(size: .aes128)
        let encryptor = try SRTEncryptor(
            sek: sek, salt: testSalt, cipherMode: .ctr, keySize: .aes128)

        let plaintext: [UInt8] = Array("test data for length check".utf8)
        let encrypted = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: SequenceNumber(1), header: [])
        #expect(encrypted.count == plaintext.count)
    }

    // MARK: - AES-GCM roundtrip

    @Test("GCM: encrypt then decrypt AES-128")
    func gcmRoundtripAES128() throws {
        let sek = makeKey(size: .aes128)
        let header: [UInt8] = [0x80, 0x00, 0x00, 0x01]
        let encryptor = try SRTEncryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes128)
        let decryptor = try SRTDecryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes128)

        let plaintext: [UInt8] = Array("GCM authenticated encryption".utf8)
        let seq = SequenceNumber(42)
        let encrypted = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: seq, header: header)
        let decrypted = try decryptor.decrypt(
            payload: encrypted, sequenceNumber: seq, header: header)
        #expect(decrypted == plaintext)
    }

    @Test("GCM: encrypt then decrypt AES-256")
    func gcmRoundtripAES256() throws {
        let sek = makeKey(size: .aes256)
        let header: [UInt8] = [0x80, 0x00, 0x00, 0x02]
        let encryptor = try SRTEncryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes256)
        let decryptor = try SRTDecryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes256)

        let plaintext: [UInt8] = Array("AES-256 GCM test".utf8)
        let seq = SequenceNumber(999)
        let encrypted = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: seq, header: header)
        let decrypted = try decryptor.decrypt(
            payload: encrypted, sequenceNumber: seq, header: header)
        #expect(decrypted == plaintext)
    }

    @Test("GCM: encrypted output is 16 bytes longer (tag)")
    func gcmTagLength() throws {
        let sek = makeKey(size: .aes128)
        let encryptor = try SRTEncryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes128)

        let plaintext: [UInt8] = Array("test".utf8)
        let encrypted = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: SequenceNumber(1), header: [])
        #expect(encrypted.count == plaintext.count + CipherMode.gcmTagSize)
    }

    @Test("GCM: tampered ciphertext fails authentication")
    func gcmTamperedCiphertext() throws {
        let sek = makeKey(size: .aes128)
        let header: [UInt8] = [0x80, 0x00]
        let encryptor = try SRTEncryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes128)
        let decryptor = try SRTDecryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes128)

        let plaintext: [UInt8] = Array("tamper test".utf8)
        var encrypted = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: SequenceNumber(1), header: header)
        encrypted[0] ^= 0xFF  // Tamper ciphertext
        #expect(throws: SRTEncryptionError.gcmAuthenticationFailure) {
            try decryptor.decrypt(
                payload: encrypted, sequenceNumber: SequenceNumber(1), header: header)
        }
    }

    @Test("GCM: tampered tag fails authentication")
    func gcmTamperedTag() throws {
        let sek = makeKey(size: .aes128)
        let header: [UInt8] = [0x80]
        let encryptor = try SRTEncryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes128)
        let decryptor = try SRTDecryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes128)

        let plaintext: [UInt8] = Array("tag tamper test".utf8)
        var encrypted = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: SequenceNumber(1), header: header)
        let lastIdx = encrypted.count - 1
        encrypted[lastIdx] ^= 0xFF  // Tamper tag
        #expect(throws: SRTEncryptionError.gcmAuthenticationFailure) {
            try decryptor.decrypt(
                payload: encrypted, sequenceNumber: SequenceNumber(1), header: header)
        }
    }

    @Test("GCM: wrong header AAD fails authentication")
    func gcmWrongHeader() throws {
        let sek = makeKey(size: .aes128)
        let encryptor = try SRTEncryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes128)
        let decryptor = try SRTDecryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes128)

        let plaintext: [UInt8] = Array("AAD mismatch test".utf8)
        let encrypted = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: SequenceNumber(1), header: [0x80, 0x00])
        #expect(throws: SRTEncryptionError.gcmAuthenticationFailure) {
            try decryptor.decrypt(
                payload: encrypted, sequenceNumber: SequenceNumber(1), header: [0x80, 0x01])
        }
    }

    @Test("GCM: payload too short throws error")
    func gcmPayloadTooShort() throws {
        let sek = makeKey(size: .aes128)
        let decryptor = try SRTDecryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes128)

        let shortPayload = [UInt8](repeating: 0, count: 10)  // Less than 16 byte tag
        #expect(throws: SRTEncryptionError.payloadTooShort(got: 10, minimumExpected: 16)) {
            try decryptor.decrypt(
                payload: shortPayload, sequenceNumber: SequenceNumber(1), header: [])
        }
    }

    // MARK: - Invalid init

    @Test("Invalid key size throws error")
    func invalidKeySize() {
        #expect(throws: SRTEncryptionError.invalidKeySize(got: 10, expected: 16)) {
            try SRTEncryptor(
                sek: [UInt8](repeating: 0, count: 10), salt: testSalt,
                cipherMode: .ctr, keySize: .aes128)
        }
    }

    @Test("Invalid salt size throws error")
    func invalidSaltSize() {
        #expect(throws: SRTEncryptionError.invalidSaltSize(got: 8)) {
            try SRTEncryptor(
                sek: [UInt8](repeating: 0, count: 16),
                salt: [UInt8](repeating: 0, count: 8),
                cipherMode: .ctr, keySize: .aes128)
        }
    }

    @Test("CTR: different keys produce different ciphertext")
    func ctrDifferentKeys() throws {
        let sek1 = [UInt8](repeating: 0xAA, count: 16)
        let sek2 = [UInt8](repeating: 0xBB, count: 16)
        let encryptor1 = try SRTEncryptor(
            sek: sek1, salt: testSalt, cipherMode: .ctr, keySize: .aes128)
        let encryptor2 = try SRTEncryptor(
            sek: sek2, salt: testSalt, cipherMode: .ctr, keySize: .aes128)

        let plaintext: [UInt8] = Array("key test".utf8)
        let seq = SequenceNumber(1)
        let enc1 = try encryptor1.encrypt(
            payload: plaintext, sequenceNumber: seq, header: [])
        let enc2 = try encryptor2.encrypt(
            payload: plaintext, sequenceNumber: seq, header: [])
        #expect(enc1 != enc2)
    }

    @Test("Decryptor invalid salt size throws error")
    func decryptorInvalidSaltSize() {
        #expect(throws: SRTEncryptionError.invalidSaltSize(got: 12)) {
            try SRTDecryptor(
                sek: [UInt8](repeating: 0, count: 16),
                salt: [UInt8](repeating: 0, count: 12),
                cipherMode: .ctr, keySize: .aes128)
        }
    }

    @Test("GCM: wrong sequence number fails decryption")
    func gcmWrongSequence() throws {
        let sek = makeKey(size: .aes128)
        let header: [UInt8] = [0x80]
        let encryptor = try SRTEncryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes128)
        let decryptor = try SRTDecryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes128)

        let plaintext: [UInt8] = Array("sequence mismatch test".utf8)
        let encrypted = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: SequenceNumber(1), header: header)
        #expect(throws: SRTEncryptionError.gcmAuthenticationFailure) {
            try decryptor.decrypt(
                payload: encrypted, sequenceNumber: SequenceNumber(2), header: header)
        }
    }
}
