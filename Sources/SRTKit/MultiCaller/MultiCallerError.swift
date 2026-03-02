// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Errors from the multi-caller subsystem.
public enum MultiCallerError: Error, Sendable, Equatable, CustomStringConvertible {
    /// Duplicate destination ID.
    case duplicateDestination(id: String)

    /// Destination not found.
    case destinationNotFound(id: String)

    /// All destinations failed.
    case allDestinationsFailed

    /// Maximum destinations reached.
    case maxDestinationsReached(max: Int)

    /// Human-readable description.
    public var description: String {
        switch self {
        case .duplicateDestination(let id):
            return "Duplicate destination: \(id)"
        case .destinationNotFound(let id):
            return "Destination not found: \(id)"
        case .allDestinationsFailed:
            return "All destinations failed"
        case .maxDestinationsReached(let max):
            return "Maximum destinations reached: \(max)"
        }
    }
}
