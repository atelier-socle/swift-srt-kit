// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Pluggable metrics backend protocol for production monitoring.
///
/// Implement this protocol to export SRT statistics to your
/// preferred monitoring system (Prometheus, StatsD, Datadog, etc.).
///
/// `export()` returns `[UInt8]` (the formatted payload) rather than
/// performing I/O. The connection actor handles sending the bytes
/// to the appropriate destination.
public protocol MetricsExporter: Sendable {
    /// Export a statistics snapshot with labels.
    ///
    /// - Parameters:
    ///   - statistics: The statistics snapshot to export.
    ///   - labels: Key-value labels to attach (e.g., connection name).
    /// - Returns: Formatted metric payload bytes.
    func export(_ statistics: SRTStatistics, labels: [String: String]) -> [UInt8]

    /// Format name for logging.
    var formatName: String { get }
}
