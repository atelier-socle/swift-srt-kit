// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Errors from the FEC subsystem.
public enum FECError: Error, Sendable, Equatable, CustomStringConvertible {
    /// Column count out of range (1–256).
    case columnsOutOfRange(got: Int)
    /// Row count out of range (1–256).
    case rowsOutOfRange(got: Int)
    /// Invalid filter string format.
    case invalidFilterString(String)
    /// Unknown layout value.
    case unknownLayout(String)
    /// Unknown ARQ mode value.
    case unknownARQMode(String)

    /// A human-readable description of the error.
    public var description: String {
        switch self {
        case .columnsOutOfRange(let got):
            return "FEC columns out of range (1-256): got \(got)"
        case .rowsOutOfRange(let got):
            return "FEC rows out of range (1-256): got \(got)"
        case .invalidFilterString(let s):
            return "Invalid FEC filter string: \(s)"
        case .unknownLayout(let s):
            return "Unknown FEC layout: \(s)"
        case .unknownARQMode(let s):
            return "Unknown FEC ARQ mode: \(s)"
        }
    }
}
