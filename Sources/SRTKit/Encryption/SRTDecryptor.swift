// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Crypto
import _CryptoExtras

/// Per-packet decryptor for SRT data packets.
///
/// Supports both AES-CTR and AES-GCM modes. In GCM mode,
/// verifies the authentication tag and rejects tampered packets.
public struct SRTDecryptor: Sendable {
    /// The cipher mode.
    private let cipherMode: CipherMode

    /// The symmetric key.
    private let symmetricKey: SymmetricKey

    /// The encryption salt (16 bytes).
    private let salt: [UInt8]

    /// Create a decryptor.
    ///
    /// - Parameters:
    ///   - sek: Stream Encrypting Key bytes.
    ///   - salt: Encryption salt (16 bytes from key derivation).
    ///   - cipherMode: CTR or GCM.
    ///   - keySize: AES key size.
    /// - Throws: ``SRTEncryptionError`` if key or salt sizes are invalid.
    public init(
        sek: [UInt8],
        salt: [UInt8],
        cipherMode: CipherMode,
        keySize: KeySize
    ) throws {
        guard sek.count == keySize.rawValue else {
            throw SRTEncryptionError.invalidKeySize(got: sek.count, expected: keySize.rawValue)
        }
        guard salt.count == KeyDerivation.saltSize else {
            throw SRTEncryptionError.invalidSaltSize(got: salt.count)
        }
        self.cipherMode = cipherMode
        self.symmetricKey = SymmetricKey(data: sek)
        self.salt = salt
    }

    /// Decrypt a data packet payload.
    ///
    /// - Parameters:
    ///   - payload: Encrypted payload (includes GCM tag if GCM mode).
    ///   - sequenceNumber: Packet sequence number.
    ///   - header: SRT packet header bytes (AAD for GCM verification).
    /// - Returns: Decrypted plaintext.
    /// - Throws: ``SRTEncryptionError`` on decryption error (GCM: tag verification failure).
    public func decrypt(
        payload: [UInt8],
        sequenceNumber: SequenceNumber,
        header: [UInt8]
    ) throws -> [UInt8] {
        switch cipherMode {
        case .ctr:
            return try decryptCTR(payload: payload, sequenceNumber: sequenceNumber)
        case .gcm:
            return try decryptGCM(
                payload: payload, sequenceNumber: sequenceNumber, header: header)
        }
    }

    // MARK: - Private

    /// Build the 16-byte CTR IV.
    private func ctrIV(sequenceNumber: SequenceNumber) -> [UInt8] {
        var iv = Array(salt[0..<12])
        let seqValue = sequenceNumber.value.bigEndian
        withUnsafeBytes(of: seqValue) { buf in
            iv.append(contentsOf: buf)
        }
        return iv
    }

    /// Build the 12-byte GCM nonce.
    private func gcmNonce(sequenceNumber: SequenceNumber) -> [UInt8] {
        var nonce = Array(salt[0..<4])
        let seqValue = sequenceNumber.value.bigEndian
        withUnsafeBytes(of: seqValue) { buf in
            nonce.append(contentsOf: buf)
        }
        nonce.append(contentsOf: [0, 0, 0, 0])
        return nonce
    }

    /// Decrypt using AES-CTR.
    private func decryptCTR(payload: [UInt8], sequenceNumber: SequenceNumber) throws -> [UInt8] {
        // CTR mode: encryption = decryption (XOR with keystream)
        let iv = ctrIV(sequenceNumber: sequenceNumber)
        let nonce = try AES._CTR.Nonce(nonceBytes: iv)
        let decrypted = try AES._CTR.encrypt(payload, using: symmetricKey, nonce: nonce)
        return Array(decrypted)
    }

    /// Decrypt using AES-GCM.
    private func decryptGCM(
        payload: [UInt8],
        sequenceNumber: SequenceNumber,
        header: [UInt8]
    ) throws -> [UInt8] {
        let tagSize = CipherMode.gcmTagSize
        guard payload.count >= tagSize else {
            throw SRTEncryptionError.payloadTooShort(
                got: payload.count, minimumExpected: tagSize)
        }

        let ciphertext = Array(payload[0..<(payload.count - tagSize)])
        let tag = Array(payload[(payload.count - tagSize)...])
        let nonceBytes = gcmNonce(sequenceNumber: sequenceNumber)
        let nonce = try AES.GCM.Nonce(data: nonceBytes)

        do {
            let sealedBox = try AES.GCM.SealedBox(
                nonce: nonce, ciphertext: ciphertext, tag: tag)
            let plaintext = try AES.GCM.open(
                sealedBox, using: symmetricKey, authenticating: header)
            return Array(plaintext)
        } catch {
            throw SRTEncryptionError.gcmAuthenticationFailure
        }
    }
}
