// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Errors from the bonding subsystem.
public enum BondingError: Error, Sendable, Equatable, CustomStringConvertible {
    /// Group is at maximum capacity.
    case groupFull(maxMembers: Int)
    /// Member not found.
    case memberNotFound(id: UInt32)
    /// Invalid status transition.
    case invalidStatusTransition(from: LinkStatus, to: LinkStatus)
    /// No active members available.
    case noActiveMembers
    /// Duplicate member ID.
    case duplicateMember(id: UInt32)

    /// A human-readable description of the error.
    public var description: String {
        switch self {
        case .groupFull(let maxMembers):
            "Group is full (max \(maxMembers) members)"
        case .memberNotFound(let id):
            "Member \(id) not found"
        case .invalidStatusTransition(let from, let to):
            "Invalid status transition from \(from) to \(to)"
        case .noActiveMembers:
            "No active members available"
        case .duplicateMember(let id):
            "Duplicate member ID \(id)"
        }
    }
}
