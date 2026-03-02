// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Errors from the multi-stream subsystem.
public enum MultiStreamError: Error, Sendable, Equatable, CustomStringConvertible {
    /// Duplicate stream ID.
    case duplicateStream(id: UInt32)

    /// Stream not found.
    case streamNotFound(id: UInt32)

    /// Maximum streams reached.
    case maxStreamsReached(max: Int)

    /// Human-readable description.
    public var description: String {
        switch self {
        case .duplicateStream(let id):
            return "Duplicate stream ID: \(id)"
        case .streamNotFound(let id):
            return "Stream not found: \(id)"
        case .maxStreamsReached(let max):
            return "Maximum streams reached: \(max)"
        }
    }
}
