// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Configuration for stream recording.
public struct RecordingConfiguration: Sendable, Equatable {
    /// Output format.
    public let format: RecordingFormat

    /// Maximum file size in bytes before rotation (nil = no limit).
    public let maxFileSizeBytes: UInt64?

    /// Maximum duration in microseconds before rotation (nil = no limit).
    public let maxDurationMicroseconds: UInt64?

    /// Flush interval in microseconds (default: 1_000_000 = 1s).
    public let flushIntervalMicroseconds: UInt64

    /// Create a recording configuration.
    ///
    /// - Parameters:
    ///   - format: Output format.
    ///   - maxFileSizeBytes: Maximum file size before rotation.
    ///   - maxDurationMicroseconds: Maximum duration before rotation.
    ///   - flushIntervalMicroseconds: Flush interval.
    public init(
        format: RecordingFormat = .mpegts,
        maxFileSizeBytes: UInt64? = nil,
        maxDurationMicroseconds: UInt64? = nil,
        flushIntervalMicroseconds: UInt64 = 1_000_000
    ) {
        self.format = format
        self.maxFileSizeBytes = maxFileSizeBytes
        self.maxDurationMicroseconds = maxDurationMicroseconds
        self.flushIntervalMicroseconds = flushIntervalMicroseconds
    }

    /// Default configuration: MPEG-TS, no limits, 1s flush.
    public static let `default` = RecordingConfiguration()
}
