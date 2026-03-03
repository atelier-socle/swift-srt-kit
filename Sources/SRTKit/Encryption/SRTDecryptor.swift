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

    /// Build the 16-byte CTR IV matching libsrt's `hcrypt_SetCtrIV`.
    ///
    /// Layout: `zeros[16]`, place pki at bytes 10-13, XOR salt[0..<14].
    /// Bytes 14-15 are the block counter (0, incremented by AES-CTR).
    private func ctrIV(sequenceNumber: SequenceNumber) -> [UInt8] {
        var iv = [UInt8](repeating: 0, count: 16)
        let seqBE = sequenceNumber.value.bigEndian
        withUnsafeBytes(of: seqBE) { buf in
            iv[10] = buf[0]
            iv[11] = buf[1]
            iv[12] = buf[2]
            iv[13] = buf[3]
        }
        for i in 0..<14 { iv[i] ^= salt[i] }
        return iv
    }

    /// Build the 12-byte GCM nonce matching libsrt's `hcrypt_SetGcmIV` (v1.5.4+).
    ///
    /// Layout: `zeros[12]`, place pki at bytes 8-11, XOR salt[0..<12].
    private func gcmNonce(sequenceNumber: SequenceNumber) -> [UInt8] {
        var nonce = [UInt8](repeating: 0, count: 12)
        let seqBE = sequenceNumber.value.bigEndian
        withUnsafeBytes(of: seqBE) { buf in
            nonce[8] = buf[0]
            nonce[9] = buf[1]
            nonce[10] = buf[2]
            nonce[11] = buf[3]
        }
        for i in 0..<12 { nonce[i] ^= salt[i] }
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
