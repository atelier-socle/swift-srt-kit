// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Errors from the SRT encryption subsystem.
public enum SRTEncryptionError: Error, Sendable, Equatable, CustomStringConvertible {
    /// Passphrase too short (minimum 10 characters).
    case passphraseTooShort(length: Int)
    /// Passphrase too long (maximum 79 characters).
    case passphraseTooLong(length: Int)
    /// Invalid salt size (expected 16 bytes).
    case invalidSaltSize(got: Int)
    /// Invalid key size.
    case invalidKeySize(got: Int, expected: Int)
    /// Key wrap integrity check failed (wrong passphrase or corrupted data).
    case keyWrapIntegrityFailure
    /// Key data length not a multiple of 8 bytes.
    case invalidKeyDataLength(got: Int)
    /// GCM authentication tag verification failed (tampered packet).
    case gcmAuthenticationFailure
    /// Encrypted payload too short (missing GCM tag).
    case payloadTooShort(got: Int, minimumExpected: Int)
    /// No key available for the requested key index.
    case noKeyAvailable(keyIndex: KeyRotation.KeyIndex)
    /// Encryption not configured.
    case notConfigured

    /// Human-readable description of the error.
    public var description: String {
        switch self {
        case .passphraseTooShort(let length):
            return "Passphrase too short: \(length) characters (minimum 10)"
        case .passphraseTooLong(let length):
            return "Passphrase too long: \(length) characters (maximum 79)"
        case .invalidSaltSize(let got):
            return "Invalid salt size: \(got) bytes (expected 16)"
        case .invalidKeySize(let got, let expected):
            return "Invalid key size: \(got) bytes (expected \(expected))"
        case .keyWrapIntegrityFailure:
            return "Key wrap integrity check failed"
        case .invalidKeyDataLength(let got):
            return "Invalid key data length: \(got) bytes (must be multiple of 8)"
        case .gcmAuthenticationFailure:
            return "GCM authentication tag verification failed"
        case .payloadTooShort(let got, let minimumExpected):
            return "Payload too short: \(got) bytes (minimum \(minimumExpected))"
        case .noKeyAvailable(let keyIndex):
            return "No key available for index \(keyIndex)"
        case .notConfigured:
            return "Encryption not configured"
        }
    }
}
