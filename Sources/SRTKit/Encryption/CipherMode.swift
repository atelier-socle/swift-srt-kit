// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// SRT encryption cipher mode.
public enum CipherMode: Sendable, Equatable, CustomStringConvertible {
    /// AES-CTR (Counter mode) — no authentication.
    case ctr
    /// AES-GCM (Galois/Counter Mode) — authenticated encryption.
    case gcm

    /// GCM authentication tag size in bytes.
    public static let gcmTagSize: Int = 16

    /// Human-readable description of the cipher mode.
    public var description: String {
        switch self {
        case .ctr: return "AES-CTR"
        case .gcm: return "AES-GCM"
        }
    }
}
