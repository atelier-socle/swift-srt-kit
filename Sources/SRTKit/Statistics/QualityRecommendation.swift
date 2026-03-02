// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Sub-scores used for quality assessment and recommendations.
public struct QualityMetrics: Sendable {
    /// Overall quality score (0.0–1.0).
    public let score: Double

    /// The statistics snapshot.
    public let statistics: SRTStatistics

    /// RTT sub-score (0.0–1.0).
    public let rttScore: Double

    /// Loss sub-score (0.0–1.0).
    public let lossScore: Double

    /// Stability sub-score (0.0–1.0).
    public let stabilityScore: Double

    /// Bitrate efficiency sub-score (0.0–1.0).
    public let bitrateEff: Double

    /// Buffer sub-score (0.0–1.0).
    public let bufferScore: Double
}

/// Generates actionable recommendations from quality metrics.
public enum QualityRecommendation: Sendable {
    /// Generate a recommendation string based on quality metrics.
    ///
    /// Rules are evaluated in priority order; first match wins.
    ///
    /// - Parameter metrics: Quality sub-scores and statistics.
    /// - Returns: Recommendation text, or nil if quality is excellent.
    public static func generate(from metrics: QualityMetrics) -> String? {
        // Rule 1: Critical quality with high loss
        if metrics.score < 0.3 && metrics.statistics.lossRate > 0.05 {
            return "Reduce bitrate significantly or increase latency"
        }

        // Rule 2: Poor quality with high RTT
        if metrics.score < 0.5 && metrics.statistics.rttMicroseconds > 200_000 {
            return "Consider increasing TSBPD latency"
        }

        // Rule 3: Fair quality with low buffer availability
        if metrics.score < 0.7 && metrics.bufferScore < 0.3 {
            return "Increase send buffer size"
        }

        // Rule 4: Nearing bandwidth capacity
        if metrics.bitrateEff > 0.95 {
            return "Nearing bandwidth capacity, consider reducing bitrate"
        }

        // Rule 5: Unstable connection
        if metrics.stabilityScore < 0.5 {
            return "Unstable connection, enable FEC for packet recovery"
        }

        // Rule 6: Excellent — no recommendation
        if metrics.score > 0.9 {
            return nil
        }

        return nil
    }
}
