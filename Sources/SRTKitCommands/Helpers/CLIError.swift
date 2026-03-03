// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Errors specific to CLI operations.
public enum CLIError: Error, CustomStringConvertible, Equatable, Sendable {
    /// Invalid command argument.
    case invalidArgument(name: String, value: String, expected: String)
    /// File not found.
    case fileNotFound(path: String)
    /// Invalid preset name.
    case invalidPreset(name: String)
    /// Invalid probe mode.
    case invalidProbeMode(name: String)
    /// Invalid target quality.
    case invalidTargetQuality(name: String)
    /// Connection failed.
    case connectionFailed(reason: String)

    /// Human-readable description of the error.
    public var description: String {
        switch self {
        case .invalidArgument(let name, let value, let expected):
            return "Invalid argument '\(name)': '\(value)' (expected: \(expected))"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .invalidPreset(let name):
            return "Invalid preset: \(name)"
        case .invalidProbeMode(let name):
            return "Invalid probe mode: \(name)"
        case .invalidTargetQuality(let name):
            return "Invalid target quality: \(name)"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        }
    }
}
