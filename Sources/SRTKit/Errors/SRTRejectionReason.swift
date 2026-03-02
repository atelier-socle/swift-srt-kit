// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Reasons why an SRT connection may be rejected.
///
/// These correspond to the SRT protocol rejection reason codes (0-17).
public enum SRTRejectionReason: UInt32, Sendable, CaseIterable, Hashable, CustomStringConvertible {
    /// Unknown rejection reason.
    case unknown = 0
    /// System error on the peer side.
    case system = 1
    /// Peer rejected the connection.
    case peer = 2
    /// Insufficient resources on the peer.
    case resource = 3
    /// Rogue connection attempt detected.
    case rogue = 4
    /// Connection backlog is full.
    case backlog = 5
    /// Internal error on the peer.
    case internalError = 6
    /// Peer is closing.
    case close = 7
    /// SRT version mismatch.
    case version = 8
    /// Rendezvous cookie mismatch.
    case rdvCookie = 9
    /// Bad encryption secret (passphrase).
    case badSecret = 10
    /// Peer requires encryption but caller has none.
    case unsecure = 11
    /// Message API mode mismatch.
    case messageAPI = 12
    /// Congestion controller mismatch.
    case congestion = 13
    /// Packet filter mismatch.
    case filter = 14
    /// Group settings mismatch.
    case group = 15
    /// Connection timed out during setup.
    case timeout = 16
    /// Crypto mode mismatch.
    case crypto = 17

    /// A human-readable description of the rejection reason.
    public var description: String {
        switch self {
        case .unknown: "Unknown"
        case .system: "System error"
        case .peer: "Peer rejected"
        case .resource: "Insufficient resources"
        case .rogue: "Rogue connection"
        case .backlog: "Backlog full"
        case .internalError: "Internal error"
        case .close: "Peer closing"
        case .version: "Version mismatch"
        case .rdvCookie: "Rendezvous cookie mismatch"
        case .badSecret: "Bad secret"
        case .unsecure: "Unsecure connection"
        case .messageAPI: "Message API mismatch"
        case .congestion: "Congestion controller mismatch"
        case .filter: "Packet filter mismatch"
        case .group: "Group settings mismatch"
        case .timeout: "Connection timeout"
        case .crypto: "Crypto mode mismatch"
        }
    }
}
