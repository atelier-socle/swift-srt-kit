// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

@preconcurrency import Crypto
@preconcurrency import _CryptoExtras

/// AES Key Wrap (RFC 3394) implementation.
///
/// Wraps and unwraps symmetric keys using AES. The wrapped output
/// is 8 bytes longer than the input (includes integrity check).
public enum KeyWrap: Sendable {
    /// RFC 3394 default Initial Value (integrity check).
    public static let defaultIV: UInt64 = 0xA6A6_A6A6_A6A6_A6A6

    /// Wrap a key using AES Key Wrap.
    ///
    /// - Parameters:
    ///   - key: The key to wrap (SEK).
    ///   - kek: The Key Encrypting Key.
    /// - Returns: Wrapped key (input length + 8 bytes).
    /// - Throws: ``SRTEncryptionError`` if key length is not a multiple of 8 bytes.
    public static func wrap(key: [UInt8], withKEK kek: [UInt8]) throws -> [UInt8] {
        guard !key.isEmpty else {
            throw SRTEncryptionError.invalidKeyDataLength(got: 0)
        }
        guard key.count % 8 == 0 else {
            throw SRTEncryptionError.invalidKeyDataLength(got: key.count)
        }

        let n = key.count / 8  // number of 64-bit blocks
        var a = ivBytes()
        var r = [[UInt8]](repeating: [], count: n)
        for i in 0..<n {
            r[i] = Array(key[(i * 8)..<((i + 1) * 8)])
        }

        let symmetricKey = SymmetricKey(data: kek)

        for j in 0...5 {
            for i in 0..<n {
                // B = AES_Encrypt(KEK, A || R[i])
                var input = [UInt8](repeating: 0, count: 16)
                input[0..<8] = a[0..<8]
                input[8..<16] = r[i][0..<8]

                let b = try aesEncryptBlock(input, key: symmetricKey)

                // A = MSB(64, B) XOR (n*j + i + 1)
                a = Array(b[0..<8])
                let t = UInt64(n * j + i + 1)
                xorUInt64IntoBytes(&a, value: t)

                // R[i] = LSB(64, B)
                r[i] = Array(b[8..<16])
            }
        }

        // C = A || R[0] || R[1] || ... || R[n-1]
        var result = a
        for i in 0..<n {
            result.append(contentsOf: r[i])
        }
        return result
    }

    /// Unwrap a key using AES Key Wrap.
    ///
    /// - Parameters:
    ///   - wrappedKey: The wrapped key.
    ///   - kek: The Key Encrypting Key.
    /// - Returns: Unwrapped key (input length - 8 bytes).
    /// - Throws: ``SRTEncryptionError`` if integrity check fails or length invalid.
    public static func unwrap(wrappedKey: [UInt8], withKEK kek: [UInt8]) throws -> [UInt8] {
        guard wrappedKey.count >= 24 else {
            throw SRTEncryptionError.invalidKeyDataLength(got: wrappedKey.count)
        }
        guard wrappedKey.count % 8 == 0 else {
            throw SRTEncryptionError.invalidKeyDataLength(got: wrappedKey.count)
        }

        let n = (wrappedKey.count / 8) - 1  // number of 64-bit key blocks
        var a = Array(wrappedKey[0..<8])
        var r = [[UInt8]](repeating: [], count: n)
        for i in 0..<n {
            r[i] = Array(wrappedKey[((i + 1) * 8)..<((i + 2) * 8)])
        }

        let symmetricKey = SymmetricKey(data: kek)

        for j in stride(from: 5, through: 0, by: -1) {
            for i in stride(from: n - 1, through: 0, by: -1) {
                // A XOR (n*j + i + 1)
                let t = UInt64(n * j + i + 1)
                xorUInt64IntoBytes(&a, value: t)

                // B = AES_Decrypt(KEK, A || R[i])
                var input = [UInt8](repeating: 0, count: 16)
                input[0..<8] = a[0..<8]
                input[8..<16] = r[i][0..<8]

                let b = try aesDecryptBlock(input, key: symmetricKey)

                // A = MSB(64, B)
                a = Array(b[0..<8])
                // R[i] = LSB(64, B)
                r[i] = Array(b[8..<16])
            }
        }

        // Verify integrity
        let expectedIV = ivBytes()
        guard a == expectedIV else {
            throw SRTEncryptionError.keyWrapIntegrityFailure
        }

        // Return R[0] || R[1] || ... || R[n-1]
        var result = [UInt8]()
        result.reserveCapacity(n * 8)
        for i in 0..<n {
            result.append(contentsOf: r[i])
        }
        return result
    }

    // MARK: - Private

    /// Convert the default IV to bytes (big-endian).
    private static func ivBytes() -> [UInt8] {
        var iv = defaultIV.bigEndian
        return withUnsafeBytes(of: &iv) { Array($0) }
    }

    /// XOR a UInt64 value into a byte array (big-endian).
    private static func xorUInt64IntoBytes(_ bytes: inout [UInt8], value: UInt64) {
        var v = value.bigEndian
        withUnsafeBytes(of: &v) { buf in
            for i in 0..<8 {
                bytes[i] ^= buf[i]
            }
        }
    }

    /// AES single-block encryption (ECB) using AES-CTR with zero nonce.
    ///
    /// CTR mode with nonce=0 and counter starting at 0: encrypting one block
    /// is equivalent to AES-ECB of that block XOR keystream. For a zero
    /// plaintext block this gives the keystream; for actual plaintext it gives
    /// AES-ECB encryption when the "plaintext" is treated as the block input.
    ///
    /// We use a different approach: encrypt zeros to get the keystream block,
    /// then XOR is not what we want. Instead, we XOR plaintext with keystream
    /// from a zero-counter nonce.
    ///
    /// Actually, AES-CTR(key, nonce=0, plaintext) = plaintext XOR AES(key, 0).
    /// That is NOT AES-ECB(key, plaintext).
    ///
    /// The correct approach: Use AES-CTR to encrypt our input block.
    /// AES-CTR output = input XOR AES_ECB(key, counter).
    /// If counter = 0, then output = input XOR AES_ECB(key, 0).
    /// We want AES_ECB(key, input). These are different.
    ///
    /// Instead, we derive AES_ECB(key, block) by:
    /// 1. Compute keystream = AES_ECB(key, nonce) via AES-CTR(zeros)
    /// 2. We can't directly get AES_ECB(key, arbitrary block) from AES-CTR
    ///
    /// Better approach: use AES._CBC from _CryptoExtras with zero IV and
    /// extract the first block, or fall back to using the GCM internals.
    ///
    /// Simplest correct approach: Use _CryptoExtras AES-CBC with zero IV.
    /// AES-CBC-Encrypt(key, IV=0, block) = AES-ECB(key, block XOR IV) = AES-ECB(key, block)
    /// (when IV is all zeros and only one block).
    private static func aesEncryptBlock(
        _ block: [UInt8],
        key: SymmetricKey
    ) throws -> [UInt8] {
        // Use AES-CTR: encrypt zeros to get keystream, then manually
        // handle block cipher. Actually the cleanest approach for RFC 3394:
        // encrypt block as data via AES-CTR where nonce is constructed
        // from the block index. But that changes the semantics.
        //
        // Correct approach: AES-CTR encrypts plaintext by XOR with keystream.
        // We need AES-ECB(key, block).
        // Trick: encrypt all-zero plaintext via CTR with nonce = block to get
        // AES(key, block) XOR 0 = AES(key, block).
        // But AES-CTR nonce is only 12 bytes, and we need the full 16-byte
        // counter block to equal our input.
        //
        // Use the _CryptoExtras approach with AES-CBC:
        let zeroIV = [UInt8](repeating: 0, count: 16)
        // Add PKCS7 padding for CBC: since our block is exactly 16 bytes,
        // we need one full block of padding (16 bytes of 0x10)
        var padded = block
        padded.append(contentsOf: [UInt8](repeating: 16, count: 16))
        let encrypted = try AES._CBC.encrypt(padded, using: key, iv: AES._CBC.IV(ivBytes: zeroIV))
        // First 16 bytes of CBC output = AES-ECB(key, block XOR 0) = AES-ECB(key, block)
        return Array(encrypted.prefix(16))
    }

    /// AES single-block decryption (ECB) using AES-CBC with zero IV.
    private static func aesDecryptBlock(
        _ block: [UInt8],
        key: SymmetricKey
    ) throws -> [UInt8] {
        // For decryption, we need to provide a block that will decrypt properly.
        // AES-CBC decrypt: first block → AES_Decrypt(key, block) XOR IV
        // With IV = 0: AES_Decrypt(key, block) XOR 0 = AES_Decrypt(key, block)
        // We need to append a valid padding block for CBC to not fail.
        // After decryption of our block, the padding check happens on the
        // padded block, not ours.
        //
        // Approach: provide our block + a block that decrypts to valid padding.
        // The second block's decryption = AES_Decrypt(key, paddingBlock) XOR ourBlock
        // We need this to be [16,16,...,16] for PKCS7.
        //
        // This is circular. Better approach: use encrypt for both directions.
        // AES_Decrypt(key, C) can be computed as:
        // Encrypt zeros with CBC, get keystream, then XOR. No, that doesn't work.
        //
        // Simplest: use the raw AES block cipher.
        // Let's compute AES_Decrypt(key, block) differently:
        // We know AES_Encrypt(key, P) = C, so AES_Decrypt(key, C) = P.
        // We can compute this by brute force XOR with CBC decrypt...
        //
        // Actually, AES-CBC with PKCS7 padding can decrypt a single block if
        // the result has valid padding. For key wrap, the decrypted block won't
        // have valid PKCS7 padding, so this approach won't work for decrypt.
        //
        // Alternative: AES-CTR is symmetric (encrypt = decrypt), so we can use
        // it, but CTR doesn't give us raw AES block cipher.
        //
        // Let's use a known trick: encrypt zero plaintext to get AES(key, counter),
        // which lets us build a lookup... No, that's impractical.
        //
        // The correct solution: use try AES._CBC.decrypt()  with careful padding handling.
        // We need to supply a two-block ciphertext where the second block decrypts
        // to valid PKCS7 padding.
        //
        // Different approach: generate the padding ciphertext block such that
        // its decryption XOR'd with our target block gives valid PKCS7 padding.
        // AES_Decrypt(key, paddingCT) XOR targetBlock = [0x10] * 16
        // AES_Decrypt(key, paddingCT) = [0x10 ^ b[i]]
        // paddingCT = AES_Encrypt(key, [0x10 ^ b[i]])
        var paddingInput = [UInt8](repeating: 0, count: 16)
        for i in 0..<16 {
            paddingInput[i] = 16 ^ block[i]
        }
        var paddingInputPadded = paddingInput
        paddingInputPadded.append(contentsOf: [UInt8](repeating: 16, count: 16))
        let secondBlockEncrypted = try AES._CBC.encrypt(
            paddingInputPadded, using: key,
            iv: AES._CBC.IV(ivBytes: [UInt8](repeating: 0, count: 16)))
        let secondBlock = Array(secondBlockEncrypted[0..<16])

        var twoBlockCiphertext = block
        twoBlockCiphertext.append(contentsOf: secondBlock)

        let decrypted = try AES._CBC.decrypt(
            twoBlockCiphertext, using: key,
            iv: AES._CBC.IV(ivBytes: [UInt8](repeating: 0, count: 16)))
        // decrypted has PKCS7 padding stripped. The first 16 bytes are our decrypted block.
        return Array(decrypted.prefix(16))
    }
}
