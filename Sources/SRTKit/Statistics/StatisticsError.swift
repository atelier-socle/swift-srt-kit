// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Errors from the statistics subsystem.
public enum StatisticsError: Error, Sendable, Equatable, CustomStringConvertible {
    /// Invalid metric value.
    case invalidMetricValue(name: String, value: String)

    /// Exporter format error.
    case exportFormatError(String)

    /// Human-readable description.
    public var description: String {
        switch self {
        case .invalidMetricValue(let name, let value):
            return "Invalid metric value for '\(name)': \(value)"
        case .exportFormatError(let detail):
            return "Export format error: \(detail)"
        }
    }
}
