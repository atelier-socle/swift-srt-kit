// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Negotiates encryption parameters during handshake.
///
/// Handles cipher field matching, enforced encryption checks,
/// and encryption mismatch detection between peers.
public enum EncryptionNegotiator: Sendable {
    /// Encryption negotiation result.
    public enum NegotiationResult: Sendable, Equatable {
        /// Both sides agree on encryption (or both unencrypted).
        case accepted(cipher: UInt16)
        /// Rejected: one side requires encryption, the other doesn't.
        case rejected(reason: SRTRejectionReason)
        /// No encryption needed (both sides unencrypted).
        case noEncryption
    }

    /// Negotiate encryption between caller and listener.
    ///
    /// Both sides exchange their cipher field and passphrase status.
    /// The listener's cipher preference wins when both sides support encryption.
    ///
    /// - Parameters:
    ///   - callerCipher: Caller's encryption field (0=none, 2=AES-128, 3=AES-192, 4=AES-256).
    ///   - listenerCipher: Listener's encryption field.
    ///   - callerHasPassphrase: Whether the caller configured a passphrase.
    ///   - listenerHasPassphrase: Whether the listener configured a passphrase.
    ///   - enforceEncryption: Whether to reject mismatched encryption (default true).
    /// - Returns: The negotiation result.
    public static func negotiate(
        callerCipher: UInt16,
        listenerCipher: UInt16,
        callerHasPassphrase: Bool,
        listenerHasPassphrase: Bool,
        enforceEncryption: Bool = true
    ) -> NegotiationResult {
        // Both unencrypted
        if !callerHasPassphrase && !listenerHasPassphrase {
            return .noEncryption
        }

        // Both have passphrase — listener's cipher wins
        if callerHasPassphrase && listenerHasPassphrase {
            return .accepted(cipher: listenerCipher)
        }

        // Mismatch: one side has passphrase, the other doesn't
        if enforceEncryption {
            return .rejected(reason: .unsecure)
        }

        // Tolerated mode: use the encrypting side's cipher
        if callerHasPassphrase {
            return .accepted(cipher: callerCipher)
        }
        return .accepted(cipher: listenerCipher)
    }
}
