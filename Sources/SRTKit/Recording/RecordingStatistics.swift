// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Statistics for an active recording.
public struct RecordingStatistics: Sendable, Equatable {
    /// Total bytes written across all files.
    public var totalBytesWritten: UInt64

    /// Duration of current recording in microseconds.
    public var durationMicroseconds: UInt64

    /// Number of file rotations performed.
    public var fileRotations: Int

    /// Bytes written to current file.
    public var currentFileBytesWritten: UInt64

    /// Number of flush operations.
    public var flushCount: Int

    /// Create empty recording statistics.
    public init() {
        self.totalBytesWritten = 0
        self.durationMicroseconds = 0
        self.fileRotations = 0
        self.currentFileBytesWritten = 0
        self.flushCount = 0
    }
}
