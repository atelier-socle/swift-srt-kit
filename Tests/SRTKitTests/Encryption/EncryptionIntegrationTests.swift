// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("Encryption Integration Tests")
struct EncryptionIntegrationTests {
    // MARK: - Full pipeline

    @Test("Full pipeline CTR AES-128: passphrase → KEK → wrap SEK → encrypt → decrypt")
    func fullPipelineCTR128() throws {
        let passphrase = "mysecretpassword"
        let salt = KeyDerivation.generateSalt()
        let keySize = KeySize.aes128

        // Derive KEK
        let kek = try KeyDerivation.deriveKEK(
            passphrase: passphrase, salt: salt, keySize: keySize)

        // Generate random SEK
        var sek = [UInt8](repeating: 0, count: keySize.rawValue)
        for i in 0..<sek.count {
            sek[i] = UInt8.random(in: 0...255)
        }

        // Wrap SEK
        let wrappedSEK = try KeyWrap.wrap(key: sek, withKEK: kek)
        #expect(wrappedSEK.count == keySize.wrappedSize)

        // Unwrap SEK
        let unwrappedSEK = try KeyWrap.unwrap(wrappedKey: wrappedSEK, withKEK: kek)
        #expect(unwrappedSEK == sek)

        // Encrypt packet
        let encryptor = try SRTEncryptor(
            sek: sek, salt: salt, cipherMode: .ctr, keySize: keySize)
        let plaintext: [UInt8] = Array("Hello SRT pipeline test!".utf8)
        let seq = SequenceNumber(1)
        let encrypted = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: seq, header: [])

        // Decrypt packet
        let decryptor = try SRTDecryptor(
            sek: unwrappedSEK, salt: salt, cipherMode: .ctr, keySize: keySize)
        let decrypted = try decryptor.decrypt(
            payload: encrypted, sequenceNumber: seq, header: [])
        #expect(decrypted == plaintext)
    }

    @Test("Full pipeline GCM AES-256: passphrase → KEK → wrap SEK → encrypt → decrypt")
    func fullPipelineGCM256() throws {
        let passphrase = "anothersecretpassphrase"
        let salt = KeyDerivation.generateSalt()
        let keySize = KeySize.aes256

        let kek = try KeyDerivation.deriveKEK(
            passphrase: passphrase, salt: salt, keySize: keySize)

        var sek = [UInt8](repeating: 0, count: keySize.rawValue)
        for i in 0..<sek.count {
            sek[i] = UInt8.random(in: 0...255)
        }

        let wrappedSEK = try KeyWrap.wrap(key: sek, withKEK: kek)
        let unwrappedSEK = try KeyWrap.unwrap(wrappedKey: wrappedSEK, withKEK: kek)

        let header: [UInt8] = [0x80, 0x00, 0x00, 0x2A]
        let encryptor = try SRTEncryptor(
            sek: sek, salt: salt, cipherMode: .gcm, keySize: keySize)
        let plaintext: [UInt8] = Array("GCM pipeline test with AAD".utf8)
        let seq = SequenceNumber(42)
        let encrypted = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: seq, header: header)

        let decryptor = try SRTDecryptor(
            sek: unwrappedSEK, salt: salt, cipherMode: .gcm, keySize: keySize)
        let decrypted = try decryptor.decrypt(
            payload: encrypted, sequenceNumber: seq, header: header)
        #expect(decrypted == plaintext)
    }

    @Test("Full pipeline AES-192")
    func fullPipeline192() throws {
        let passphrase = "pipeline192test!"
        let salt = KeyDerivation.generateSalt()
        let keySize = KeySize.aes192

        let kek = try KeyDerivation.deriveKEK(
            passphrase: passphrase, salt: salt, keySize: keySize)
        var sek = [UInt8](repeating: 0, count: keySize.rawValue)
        for i in 0..<sek.count {
            sek[i] = UInt8.random(in: 0...255)
        }

        let wrappedSEK = try KeyWrap.wrap(key: sek, withKEK: kek)
        let unwrappedSEK = try KeyWrap.unwrap(wrappedKey: wrappedSEK, withKEK: kek)
        #expect(unwrappedSEK == sek)

        let encryptor = try SRTEncryptor(
            sek: sek, salt: salt, cipherMode: .ctr, keySize: keySize)
        let decryptor = try SRTDecryptor(
            sek: unwrappedSEK, salt: salt, cipherMode: .ctr, keySize: keySize)

        let plaintext: [UInt8] = Array("AES-192 full pipeline".utf8)
        let encrypted = try encryptor.encrypt(
            payload: plaintext, sequenceNumber: SequenceNumber(10), header: [])
        let decrypted = try decryptor.decrypt(
            payload: encrypted, sequenceNumber: SequenceNumber(10), header: [])
        #expect(decrypted == plaintext)
    }

    // MARK: - Wrong passphrase

    @Test("Wrong passphrase → unwrap fails with integrity error")
    func wrongPassphrase() throws {
        let salt = KeyDerivation.generateSalt()
        let keySize = KeySize.aes128

        let kek1 = try KeyDerivation.deriveKEK(
            passphrase: "correctpassword",
            salt: salt,
            keySize: keySize
        )
        let sek = [UInt8](repeating: 0xAA, count: 16)
        let wrappedSEK = try KeyWrap.wrap(key: sek, withKEK: kek1)

        // Try to unwrap with wrong passphrase
        let kek2 = try KeyDerivation.deriveKEK(
            passphrase: "wrongpassphrase",
            salt: salt,
            keySize: keySize
        )
        #expect(throws: SRTEncryptionError.keyWrapIntegrityFailure) {
            try KeyWrap.unwrap(wrappedKey: wrappedSEK, withKEK: kek2)
        }
    }

    // MARK: - Key rotation

    @Test("Key rotation: encrypt N packets, rotate, continue encrypting")
    func keyRotationCTR() throws {
        let salt = KeyDerivation.generateSalt()
        let keySize = KeySize.aes128

        let sek1 = [UInt8](repeating: 0xAA, count: 16)
        let sek2 = [UInt8](repeating: 0xBB, count: 16)

        let encryptor1 = try SRTEncryptor(
            sek: sek1, salt: salt, cipherMode: .ctr, keySize: keySize)
        let encryptor2 = try SRTEncryptor(
            sek: sek2, salt: salt, cipherMode: .ctr, keySize: keySize)
        let decryptor1 = try SRTDecryptor(
            sek: sek1, salt: salt, cipherMode: .ctr, keySize: keySize)
        let decryptor2 = try SRTDecryptor(
            sek: sek2, salt: salt, cipherMode: .ctr, keySize: keySize)

        let plaintext: [UInt8] = Array("rotation test".utf8)

        // Encrypt with key 1
        let enc1 = try encryptor1.encrypt(
            payload: plaintext, sequenceNumber: SequenceNumber(1), header: [])
        let dec1 = try decryptor1.decrypt(
            payload: enc1, sequenceNumber: SequenceNumber(1), header: [])
        #expect(dec1 == plaintext)

        // Encrypt with key 2 (after rotation)
        let enc2 = try encryptor2.encrypt(
            payload: plaintext, sequenceNumber: SequenceNumber(2), header: [])
        let dec2 = try decryptor2.decrypt(
            payload: enc2, sequenceNumber: SequenceNumber(2), header: [])
        #expect(dec2 == plaintext)

        // Different keys produce different ciphertext
        #expect(enc1 != enc2)
    }

    @Test("Key rotation with GCM mode")
    func keyRotationGCM() throws {
        let salt = KeyDerivation.generateSalt()
        let keySize = KeySize.aes256
        let header: [UInt8] = [0x80, 0x00]

        let sek1 = [UInt8](repeating: 0x11, count: 32)
        let sek2 = [UInt8](repeating: 0x22, count: 32)

        let encryptor1 = try SRTEncryptor(
            sek: sek1, salt: salt, cipherMode: .gcm, keySize: keySize)
        let decryptor1 = try SRTDecryptor(
            sek: sek1, salt: salt, cipherMode: .gcm, keySize: keySize)
        let encryptor2 = try SRTEncryptor(
            sek: sek2, salt: salt, cipherMode: .gcm, keySize: keySize)
        let decryptor2 = try SRTDecryptor(
            sek: sek2, salt: salt, cipherMode: .gcm, keySize: keySize)

        let plaintext: [UInt8] = Array("GCM rotation".utf8)

        let enc1 = try encryptor1.encrypt(
            payload: plaintext, sequenceNumber: SequenceNumber(1), header: header)
        let dec1 = try decryptor1.decrypt(
            payload: enc1, sequenceNumber: SequenceNumber(1), header: header)
        #expect(dec1 == plaintext)

        let enc2 = try encryptor2.encrypt(
            payload: plaintext, sequenceNumber: SequenceNumber(2), header: header)
        let dec2 = try decryptor2.decrypt(
            payload: enc2, sequenceNumber: SequenceNumber(2), header: header)
        #expect(dec2 == plaintext)
    }

    @Test("KeyRotation state machine lifecycle")
    func rotationStateMachine() {
        var rotation = KeyRotation(configuration: .init(refreshRate: 50, preAnnounce: 5))
        let evenKey: [UInt8] = [1, 2, 3, 4]
        let oddKey: [UInt8] = [5, 6, 7, 8]
        rotation.setKey(evenKey, for: .even)
        rotation.setKey(oddKey, for: .odd)

        #expect(rotation.activeKey == evenKey)

        // Advance to preAnnounce threshold (50 - 5 = 45)
        var preAnnounced = false
        var switched = false
        for _ in 0..<50 {
            let action = rotation.packetSent()
            if case .preAnnounce = action { preAnnounced = true }
            if case .switchKey = action { switched = true }
        }
        #expect(preAnnounced)
        #expect(switched)

        rotation.completeRotation()
        #expect(rotation.activeKey == oddKey)
    }

    @Test("Multiple packets with unique sequence numbers all decrypt correctly")
    func manyPackets() throws {
        let sek = [UInt8](repeating: 0x42, count: 16)
        let salt = KeyDerivation.generateSalt()
        let encryptor = try SRTEncryptor(
            sek: sek, salt: salt, cipherMode: .ctr, keySize: .aes128)
        let decryptor = try SRTDecryptor(
            sek: sek, salt: salt, cipherMode: .ctr, keySize: .aes128)

        for i: UInt32 in 0..<100 {
            let plaintext = Array("packet \(i)".utf8)
            let seq = SequenceNumber(i)
            let encrypted = try encryptor.encrypt(
                payload: plaintext, sequenceNumber: seq, header: [])
            let decrypted = try decryptor.decrypt(
                payload: encrypted, sequenceNumber: seq, header: [])
            #expect(decrypted == plaintext)
        }
    }
}
