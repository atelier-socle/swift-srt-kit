// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Estimates round-trip time using EWMA (Exponentially Weighted Moving Average).
///
/// Uses the standard SRT RTT estimation formulas:
/// ```
/// RTT_smoothed = 7/8 * RTT_smoothed + 1/8 * RTT_new
/// RTT_variance = 3/4 * RTT_variance + 1/4 * |RTT_smoothed - RTT_new|
/// ```
public struct RTTEstimator: Sendable {
    /// SYN interval in microseconds (10ms).
    public static let synInterval: UInt64 = 10_000

    /// Current smoothed RTT estimate in microseconds.
    public private(set) var smoothedRTT: UInt64

    /// Current RTT variance in microseconds.
    public private(set) var variance: UInt64

    /// Number of RTT samples received.
    public private(set) var sampleCount: Int

    /// Create an RTT estimator.
    ///
    /// - Parameter initialRTT: Initial RTT estimate in microseconds (default: 100_000 = 100ms).
    public init(initialRTT: UInt64 = 100_000) {
        self.smoothedRTT = initialRTT
        self.variance = initialRTT / 2
        self.sampleCount = 0
    }

    /// Update the RTT estimate with a new measurement.
    ///
    /// The first sample initializes smoothedRTT directly. Subsequent
    /// samples use the EWMA formula.
    /// - Parameter rtt: Measured RTT in microseconds.
    public mutating func update(rtt: UInt64) {
        sampleCount += 1

        if sampleCount == 1 {
            smoothedRTT = rtt
            variance = rtt / 2
            return
        }

        // EWMA: smoothedRTT = (7 * smoothedRTT + rtt) / 8
        smoothedRTT = (7 * smoothedRTT + rtt) / 8

        // Variance: variance = (3 * variance + |smoothedRTT - rtt|) / 4
        let diff = absDiff(smoothedRTT, rtt)
        variance = (3 * variance + diff) / 4
    }

    /// Calculate the NAK period: 4 * RTT + RTTVar + SYN_INTERVAL.
    ///
    /// SYN_INTERVAL = 10ms = 10_000 µs.
    public var nakPeriod: UInt64 {
        4 * smoothedRTT + variance + Self.synInterval
    }

    /// Absolute difference between two unsigned values.
    private func absDiff(_ a: UInt64, _ b: UInt64) -> UInt64 {
        a > b ? a - b : b - a
    }
}
