// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// AES key size for SRT encryption.
public enum KeySize: Int, Sendable, CaseIterable {
    /// AES-128 (16 bytes).
    case aes128 = 16
    /// AES-192 (24 bytes).
    case aes192 = 24
    /// AES-256 (32 bytes).
    case aes256 = 32

    /// Size of the wrapped key (key + 8 bytes for integrity check).
    public var wrappedSize: Int { rawValue + 8 }

    /// Encryption field value for handshake (2=128, 3=192, 4=256).
    public var handshakeValue: UInt16 {
        switch self {
        case .aes128: return 2
        case .aes192: return 3
        case .aes256: return 4
        }
    }

    /// Create from handshake encryption field value.
    ///
    /// - Parameter handshakeValue: Encryption field from handshake (2, 3, or 4).
    public init?(handshakeValue: UInt16) {
        switch handshakeValue {
        case 2: self = .aes128
        case 3: self = .aes192
        case 4: self = .aes256
        default: return nil
        }
    }
}
