// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Role of a peer in the rendezvous handshake.
///
/// Determined by comparing Socket IDs: the larger ID is the Initiator,
/// the smaller ID is the Responder. If IDs are equal (astronomically unlikely),
/// the handshake cannot proceed.
public enum RendezvousRole: String, Sendable, CustomStringConvertible {
    /// The peer that sends HSREQ (larger Socket ID).
    case initiator
    /// The peer that sends HSRSP (smaller Socket ID).
    case responder

    /// Determine role by comparing local and remote Socket IDs.
    ///
    /// - Parameters:
    ///   - localSocketID: The local peer's socket identifier.
    ///   - remoteSocketID: The remote peer's socket identifier.
    /// - Returns: The role for the local peer, or nil if IDs are equal.
    public static func determine(
        localSocketID: UInt32,
        remoteSocketID: UInt32
    ) -> RendezvousRole? {
        if localSocketID > remoteSocketID {
            return .initiator
        } else if localSocketID < remoteSocketID {
            return .responder
        }
        return nil
    }

    /// A human-readable description of the role.
    public var description: String { rawValue }
}
