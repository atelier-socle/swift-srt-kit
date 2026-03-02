// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTEncryptor GCM Extended Tests")
struct SRTEncryptorGCMTests {
    private let testSalt: [UInt8] = [
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10
    ]

    @Test("GCM: different headers produce different tags")
    func differentHeaders() throws {
        let sek = [UInt8](repeating: 0xAB, count: 16)
        let encryptor = try SRTEncryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes128)

        let plaintext: [UInt8] = Array("test data".utf8)
        let seq = SequenceNumber(1)

        let enc1 = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: seq, header: [0x80, 0x00])
        let enc2 = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: seq, header: [0x80, 0x01])
        // Ciphertext is the same but tags differ
        #expect(enc1 != enc2)
    }

    @Test("GCM: empty payload with tag roundtrip")
    func gcmEmptyPayload() throws {
        let sek = [UInt8](repeating: 0xAB, count: 16)
        let encryptor = try SRTEncryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes128)
        let decryptor = try SRTDecryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes128)

        let header: [UInt8] = [0x80]
        let encrypted = try encryptor.encrypt(
            payload: [], sequenceNumber: SequenceNumber(1), header: header)
        // Empty payload + 16-byte tag = 16 bytes
        #expect(encrypted.count == 16)
        let decrypted = try decryptor.decrypt(
            payload: encrypted, sequenceNumber: SequenceNumber(1), header: header)
        #expect(decrypted.isEmpty)
    }

    @Test("GCM: large payload roundtrip")
    func gcmLargePayload() throws {
        let sek = [UInt8](repeating: 0xAB, count: 32)
        let encryptor = try SRTEncryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes256)
        let decryptor = try SRTDecryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes256)

        let plaintext = [UInt8](repeating: 0x55, count: 8192)
        let header: [UInt8] = [0x80, 0x00, 0x00, 0x01]
        let seq = SequenceNumber(12345)
        let encrypted = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: seq, header: header)
        let decrypted = try decryptor.decrypt(
            payload: encrypted, sequenceNumber: seq, header: header)
        #expect(decrypted == plaintext)
    }

    @Test("GCM: different sequence numbers with same plaintext")
    func gcmDifferentSequences() throws {
        let sek = [UInt8](repeating: 0xAB, count: 16)
        let encryptor = try SRTEncryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes128)

        let plaintext: [UInt8] = Array("seq test".utf8)
        let header: [UInt8] = [0x80]
        let enc1 = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: SequenceNumber(1), header: header)
        let enc2 = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: SequenceNumber(2), header: header)
        #expect(enc1 != enc2)
    }

    @Test("GCM: empty header AAD still works")
    func gcmEmptyHeader() throws {
        let sek = [UInt8](repeating: 0xAB, count: 16)
        let encryptor = try SRTEncryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes128)
        let decryptor = try SRTDecryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes128)

        let plaintext: [UInt8] = Array("no header test".utf8)
        let encrypted = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: SequenceNumber(1), header: [])
        let decrypted = try decryptor.decrypt(
            payload: encrypted, sequenceNumber: SequenceNumber(1), header: [])
        #expect(decrypted == plaintext)
    }

    @Test("GCM AES-192 roundtrip")
    func gcm192Roundtrip() throws {
        let sek = [UInt8](repeating: 0xCD, count: 24)
        let encryptor = try SRTEncryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes192)
        let decryptor = try SRTDecryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes192)

        let plaintext: [UInt8] = Array("AES-192 GCM".utf8)
        let header: [UInt8] = [0x80, 0x00]
        let encrypted = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: SequenceNumber(42), header: header)
        let decrypted = try decryptor.decrypt(
            payload: encrypted, sequenceNumber: SequenceNumber(42), header: header)
        #expect(decrypted == plaintext)
    }

    @Test("CTR ciphertext cannot be decrypted by GCM decryptor")
    func crossModeCTRtoGCM() throws {
        let sek = [UInt8](repeating: 0xAB, count: 16)
        let ctrEncryptor = try SRTEncryptor(
            sek: sek, salt: testSalt, cipherMode: .ctr, keySize: .aes128)
        let gcmDecryptor = try SRTDecryptor(
            sek: sek, salt: testSalt, cipherMode: .gcm, keySize: .aes128)

        let plaintext: [UInt8] = Array("cross mode test data padding!".utf8)
        let encrypted = try ctrEncryptor.encrypt(
            payload: plaintext, sequenceNumber: SequenceNumber(1), header: [])
        // CTR output is same size as plaintext. GCM needs at least 16 bytes for tag.
        // If plaintext is long enough (>=16), GCM decrypt will fail with auth error.
        #expect(throws: SRTEncryptionError.gcmAuthenticationFailure) {
            try gcmDecryptor.decrypt(
                payload: encrypted, sequenceNumber: SequenceNumber(1), header: [])
        }
    }

    @Test("GCM tag size is 16")
    func gcmTagSizeConstant() {
        #expect(CipherMode.gcmTagSize == 16)
    }

    @Test("CipherMode equatable")
    func cipherModeEquatable() {
        #expect(CipherMode.ctr == CipherMode.ctr)
        #expect(CipherMode.gcm == CipherMode.gcm)
        #expect(CipherMode.ctr != CipherMode.gcm)
    }
}
