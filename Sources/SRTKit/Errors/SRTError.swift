// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Errors that can occur during SRT operations.
///
/// Organized by category: connection, encryption, handshake, packet,
/// configuration, group, and socket errors.
public enum SRTError: Error, Sendable, Hashable, CustomStringConvertible {
    // MARK: - Connection

    /// The connection attempt failed.
    case connectionFailed(String)
    /// The connection attempt timed out.
    case connectionTimeout
    /// The connection was rejected by the remote peer.
    case connectionRejected(SRTRejectionReason)
    /// The connection was closed.
    case connectionClosed

    // MARK: - Encryption

    /// Encryption of data failed.
    case encryptionFailed(String)
    /// Decryption of data failed.
    case decryptionFailed(String)
    /// The provided passphrase is invalid.
    case invalidPassphrase

    // MARK: - Handshake

    /// The handshake process failed.
    case handshakeFailed(String)
    /// The handshake timed out.
    case handshakeTimeout
    /// The SRT version is not compatible.
    case versionMismatch

    // MARK: - Packet

    /// The received packet is invalid.
    case invalidPacket(String)
    /// The packet exceeds the maximum allowed size.
    case packetTooLarge(Int)

    // MARK: - Configuration

    /// An invalid option was specified.
    case invalidOption(String)
    /// The option is not applicable in the current context.
    case optionNotApplicable(String)

    // MARK: - Group

    /// A group operation failed.
    case groupFailed(String)
    /// All links in the connection group are down.
    case allLinksDown
    /// The specified group member was not found.
    case memberNotFound(String)

    // MARK: - Socket

    /// Failed to create the socket.
    case socketCreationFailed(String)
    /// The socket is in an invalid state for the requested operation.
    case invalidState(SRTSocketState)
    /// An internal error occurred.
    case internalError(String)

    /// A human-readable description of the error.
    public var description: String {
        switch self {
        case .connectionFailed(let reason):
            "Connection failed: \(reason)"
        case .connectionTimeout:
            "Connection timed out"
        case .connectionRejected(let reason):
            "Connection rejected: \(reason)"
        case .connectionClosed:
            "Connection closed"
        case .encryptionFailed(let reason):
            "Encryption failed: \(reason)"
        case .decryptionFailed(let reason):
            "Decryption failed: \(reason)"
        case .invalidPassphrase:
            "Invalid passphrase"
        case .handshakeFailed(let reason):
            "Handshake failed: \(reason)"
        case .handshakeTimeout:
            "Handshake timed out"
        case .versionMismatch:
            "SRT version mismatch"
        case .invalidPacket(let reason):
            "Invalid packet: \(reason)"
        case .packetTooLarge(let size):
            "Packet too large: \(size) bytes"
        case .invalidOption(let name):
            "Invalid option: \(name)"
        case .optionNotApplicable(let name):
            "Option not applicable: \(name)"
        case .groupFailed(let reason):
            "Group failed: \(reason)"
        case .allLinksDown:
            "All links down"
        case .memberNotFound(let identifier):
            "Member not found: \(identifier)"
        case .socketCreationFailed(let reason):
            "Socket creation failed: \(reason)"
        case .invalidState(let state):
            "Invalid state: \(state)"
        case .internalError(let reason):
            "Internal error: \(reason)"
        }
    }
}
