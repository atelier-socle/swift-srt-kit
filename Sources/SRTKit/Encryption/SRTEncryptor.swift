// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Crypto
import _CryptoExtras

/// Per-packet encryptor for SRT data packets.
///
/// Supports both AES-CTR and AES-GCM modes. Uses the Stream
/// Encrypting Key (SEK) and packet sequence number to ensure
/// each packet has a unique IV/nonce.
public struct SRTEncryptor: Sendable {
    /// The cipher mode.
    private let cipherMode: CipherMode

    /// The symmetric key.
    private let symmetricKey: SymmetricKey

    /// The encryption salt (16 bytes).
    private let salt: [UInt8]

    /// Create an encryptor.
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

    /// Encrypt a data packet payload.
    ///
    /// - Parameters:
    ///   - payload: Plaintext payload bytes.
    ///   - sequenceNumber: Packet sequence number (for IV/nonce construction).
    ///   - header: SRT packet header bytes (used as AAD in GCM mode).
    /// - Returns: Encrypted payload (same size for CTR, +16 bytes for GCM tag).
    /// - Throws: Encryption error.
    public func encrypt(
        payload: [UInt8],
        sequenceNumber: SequenceNumber,
        header: [UInt8]
    ) throws -> [UInt8] {
        switch cipherMode {
        case .ctr:
            return try encryptCTR(payload: payload, sequenceNumber: sequenceNumber)
        case .gcm:
            return try encryptGCM(
                payload: payload, sequenceNumber: sequenceNumber, header: header)
        }
    }

    // MARK: - Private

    /// Build the 16-byte CTR IV: salt[0..<12] || sequenceNumber (4 bytes big-endian).
    private func ctrIV(sequenceNumber: SequenceNumber) -> [UInt8] {
        var iv = Array(salt[0..<12])
        let seqValue = sequenceNumber.value.bigEndian
        withUnsafeBytes(of: seqValue) { buf in
            iv.append(contentsOf: buf)
        }
        return iv
    }

    /// Build the 12-byte GCM nonce: salt[0..<4] || sequenceNumber (4 bytes) || 0x00000000.
    private func gcmNonce(sequenceNumber: SequenceNumber) -> [UInt8] {
        var nonce = Array(salt[0..<4])
        let seqValue = sequenceNumber.value.bigEndian
        withUnsafeBytes(of: seqValue) { buf in
            nonce.append(contentsOf: buf)
        }
        nonce.append(contentsOf: [0, 0, 0, 0])
        return nonce
    }

    /// Encrypt using AES-CTR.
    private func encryptCTR(payload: [UInt8], sequenceNumber: SequenceNumber) throws -> [UInt8] {
        let iv = ctrIV(sequenceNumber: sequenceNumber)
        let nonce = try AES._CTR.Nonce(nonceBytes: iv)
        let encrypted = try AES._CTR.encrypt(payload, using: symmetricKey, nonce: nonce)
        return Array(encrypted)
    }

    /// Encrypt using AES-GCM.
    private func encryptGCM(
        payload: [UInt8],
        sequenceNumber: SequenceNumber,
        header: [UInt8]
    ) throws -> [UInt8] {
        let nonceBytes = gcmNonce(sequenceNumber: sequenceNumber)
        let nonce = try AES.GCM.Nonce(data: nonceBytes)
        let sealedBox = try AES.GCM.seal(
            payload, using: symmetricKey, nonce: nonce, authenticating: header)
        // Return ciphertext + tag
        var result = Array(sealedBox.ciphertext)
        result.append(contentsOf: sealedBox.tag)
        return result
    }
}
