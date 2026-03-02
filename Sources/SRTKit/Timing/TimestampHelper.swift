// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Utility functions for SRT 32-bit timestamp arithmetic.
///
/// SRT timestamps are 32-bit unsigned microsecond values that wrap
/// around every ~71.5 minutes (2^32 µs ≈ 4295 seconds).
public enum TimestampHelper: Sendable {
    /// Maximum timestamp value before wrap-around.
    public static let maxTimestamp: UInt32 = .max

    /// Duration of one full timestamp cycle in microseconds.
    public static let wrapPeriod: UInt64 = UInt64(UInt32.max) + 1

    /// Calculate the signed difference between two timestamps,
    /// handling wrap-around correctly.
    ///
    /// Uses signed 32-bit interpretation of the subtraction to
    /// handle wrap-around: when `t2` has just wrapped past `t1`,
    /// the result is a small positive value.
    /// - Parameters:
    ///   - t2: The later timestamp.
    ///   - t1: The earlier timestamp.
    /// - Returns: Signed difference (t2 - t1) as Int64.
    public static func difference(_ t2: UInt32, _ t1: UInt32) -> Int64 {
        Int64(Int32(bitPattern: t2 &- t1))
    }

    /// Check if timestamp `t2` is after `t1`, handling wrap-around.
    ///
    /// - Parameters:
    ///   - t2: The timestamp to check.
    ///   - t1: The reference timestamp.
    /// - Returns: `true` if `t2` is logically after `t1`.
    public static func isAfter(_ t2: UInt32, _ t1: UInt32) -> Bool {
        difference(t2, t1) > 0
    }

    /// Add a signed offset to a timestamp, handling wrap-around.
    ///
    /// - Parameters:
    ///   - timestamp: The base timestamp.
    ///   - offset: Signed offset in microseconds.
    /// - Returns: The resulting timestamp after adding the offset.
    public static func add(_ timestamp: UInt32, offset: Int64) -> UInt32 {
        UInt32(truncatingIfNeeded: Int64(timestamp) &+ offset)
    }

    /// Convert milliseconds to microseconds.
    ///
    /// - Parameter ms: Duration in milliseconds.
    /// - Returns: Duration in microseconds.
    public static func msToUs(_ ms: UInt64) -> UInt64 {
        ms * 1000
    }

    /// Convert microseconds to milliseconds (truncating).
    ///
    /// - Parameter us: Duration in microseconds.
    /// - Returns: Duration in milliseconds (truncated).
    public static func usToMs(_ us: UInt64) -> UInt64 {
        us / 1000
    }
}
