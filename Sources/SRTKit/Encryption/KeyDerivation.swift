// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Crypto

/// PBKDF2-HMAC-SHA1 key derivation for SRT.
///
/// Derives a Key Encrypting Key (KEK) from a passphrase and salt
/// using PBKDF2 with HMAC-SHA1 as the PRF.
public enum KeyDerivation: Sendable {
    /// Default iteration count for PBKDF2.
    public static let defaultIterations: Int = 2048

    /// Salt size in bytes.
    public static let saltSize: Int = 16

    /// Minimum passphrase length.
    public static let minPassphraseLength: Int = 10

    /// Maximum passphrase length.
    public static let maxPassphraseLength: Int = 79

    /// Derive a KEK from a passphrase and salt.
    ///
    /// - Parameters:
    ///   - passphrase: User passphrase (10–79 characters).
    ///   - salt: Random salt (16 bytes).
    ///   - keySize: Desired key size.
    ///   - iterations: PBKDF2 iterations (default: 2048).
    /// - Returns: Derived key bytes.
    /// - Throws: ``SRTEncryptionError`` if passphrase is invalid or salt size wrong.
    public static func deriveKEK(
        passphrase: String,
        salt: [UInt8],
        keySize: KeySize,
        iterations: Int = defaultIterations
    ) throws -> [UInt8] {
        try validatePassphrase(passphrase)
        guard salt.count == saltSize else {
            throw SRTEncryptionError.invalidSaltSize(got: salt.count)
        }
        let passphraseBytes = Array(passphrase.utf8)
        return pbkdf2HMACSHA1(
            password: passphraseBytes,
            salt: salt,
            iterations: iterations,
            derivedKeyLength: keySize.rawValue
        )
    }

    /// Generate a random salt.
    ///
    /// - Returns: 16 random bytes.
    public static func generateSalt() -> [UInt8] {
        var rng = SystemRandomNumberGenerator()
        var salt = [UInt8](repeating: 0, count: saltSize)
        for i in 0..<saltSize {
            salt[i] = UInt8.random(in: 0...255, using: &rng)
        }
        return salt
    }

    /// Validate a passphrase (10–79 characters).
    ///
    /// - Parameter passphrase: The passphrase to validate.
    /// - Throws: ``SRTEncryptionError`` if passphrase is too short or too long.
    public static func validatePassphrase(_ passphrase: String) throws {
        let length = passphrase.count
        if length < minPassphraseLength {
            throw SRTEncryptionError.passphraseTooShort(length: length)
        }
        if length > maxPassphraseLength {
            throw SRTEncryptionError.passphraseTooLong(length: length)
        }
    }

    // MARK: - PBKDF2 Implementation

    /// PBKDF2 with HMAC-SHA1 as the PRF.
    ///
    /// - Parameters:
    ///   - password: Password bytes.
    ///   - salt: Salt bytes.
    ///   - iterations: Iteration count.
    ///   - derivedKeyLength: Desired output key length in bytes.
    /// - Returns: Derived key bytes.
    private static func pbkdf2HMACSHA1(
        password: [UInt8],
        salt: [UInt8],
        iterations: Int,
        derivedKeyLength: Int
    ) -> [UInt8] {
        let hashLength = 20  // SHA-1 output = 20 bytes
        let blockCount = (derivedKeyLength + hashLength - 1) / hashLength
        let key = SymmetricKey(data: password)
        var derivedKey = [UInt8]()
        derivedKey.reserveCapacity(derivedKeyLength)

        for blockIndex in 1...blockCount {
            // U_1 = HMAC(password, salt || INT(blockIndex))
            var saltPlusIndex = salt
            saltPlusIndex.append(UInt8((blockIndex >> 24) & 0xFF))
            saltPlusIndex.append(UInt8((blockIndex >> 16) & 0xFF))
            saltPlusIndex.append(UInt8((blockIndex >> 8) & 0xFF))
            saltPlusIndex.append(UInt8(blockIndex & 0xFF))

            var u = hmacSHA1(key: key, data: saltPlusIndex)
            var result = u

            // U_2 .. U_c
            for _ in 1..<iterations {
                u = hmacSHA1(key: key, data: u)
                for j in 0..<hashLength {
                    result[j] ^= u[j]
                }
            }

            derivedKey.append(contentsOf: result)
        }

        return Array(derivedKey.prefix(derivedKeyLength))
    }

    /// Compute HMAC-SHA1.
    private static func hmacSHA1(key: SymmetricKey, data: [UInt8]) -> [UInt8] {
        let mac = HMAC<Insecure.SHA1>.authenticationCode(for: data, using: key)
        return Array(mac)
    }
}
