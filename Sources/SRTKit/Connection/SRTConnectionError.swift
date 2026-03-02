// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Errors from the connection layer.
public enum SRTConnectionError: Error, Sendable, Equatable, CustomStringConvertible {
    /// Connection attempt timed out.
    case connectionTimeout
    /// Handshake rejected by peer.
    case handshakeRejected(reason: String)
    /// Connection broken (keepalive timeout).
    case connectionBroken
    /// Not in a state that allows this operation.
    case invalidState(current: SRTConnectionState, required: String)
    /// Send buffer full.
    case bufferFull
    /// Listener already started.
    case alreadyListening
    /// Bind failed.
    case bindFailed(String)
    /// Encryption mismatch with peer.
    case encryptionMismatch
    /// Peer requires encryption but none configured.
    case encryptionRequired

    /// Human-readable description.
    public var description: String {
        switch self {
        case .connectionTimeout:
            return "Connection attempt timed out"
        case .handshakeRejected(let reason):
            return "Handshake rejected: \(reason)"
        case .connectionBroken:
            return "Connection broken (keepalive timeout)"
        case .invalidState(let current, let required):
            return "Invalid state \(current.rawValue), required: \(required)"
        case .bufferFull:
            return "Send buffer full"
        case .alreadyListening:
            return "Listener already started"
        case .bindFailed(let reason):
            return "Bind failed: \(reason)"
        case .encryptionMismatch:
            return "Encryption mismatch with peer"
        case .encryptionRequired:
            return "Peer requires encryption but none configured"
        }
    }
}
