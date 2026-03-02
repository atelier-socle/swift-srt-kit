// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Connection quality assessment derived from statistics.
///
/// Uses a weighted composite score combining RTT, loss rate,
/// buffer utilization, bandwidth efficiency, and stability.
public struct SRTConnectionQuality: Sendable, Equatable {
    /// Quality grade.
    public enum Grade: String, Sendable, CaseIterable, Comparable, CustomStringConvertible {
        /// Excellent quality (score > 0.9).
        case excellent
        /// Good quality (score > 0.7).
        case good
        /// Fair quality (score > 0.5).
        case fair
        /// Poor quality (score > 0.3).
        case poor
        /// Critical quality (score <= 0.3).
        case critical

        /// Human-readable description.
        public var description: String { rawValue }

        /// Ordering: excellent > good > fair > poor > critical.
        public static func < (lhs: Grade, rhs: Grade) -> Bool {
            let order: [Grade] = [.critical, .poor, .fair, .good, .excellent]
            guard let lhsIndex = order.firstIndex(of: lhs),
                let rhsIndex = order.firstIndex(of: rhs)
            else { return false }
            return lhsIndex < rhsIndex
        }
    }

    /// Overall quality score (0.0–1.0).
    public let score: Double

    /// Quality grade derived from score.
    public let grade: Grade

    /// RTT sub-score (0.0–1.0).
    public let rttScore: Double

    /// Loss sub-score (0.0–1.0).
    public let lossScore: Double

    /// Buffer sub-score (0.0–1.0).
    public let bufferScore: Double

    /// Bitrate efficiency sub-score (0.0–1.0).
    public let bitrateEfficiencyScore: Double

    /// Stability sub-score (0.0–1.0).
    public let stabilityScore: Double

    /// Actionable recommendation (nil if excellent).
    public let recommendation: String?

    /// Weight for RTT score component.
    public static let rttWeight: Double = 0.30

    /// Weight for loss score component.
    public static let lossWeight: Double = 0.25

    /// Weight for buffer score component.
    public static let bufferWeight: Double = 0.20

    /// Weight for bitrate efficiency score component.
    public static let bitrateWeight: Double = 0.15

    /// Weight for stability score component.
    public static let stabilityWeight: Double = 0.10

    /// Compute quality from statistics.
    ///
    /// - Parameter statistics: A statistics snapshot.
    /// - Returns: Quality assessment with score, grade, and recommendation.
    public static func from(statistics: SRTStatistics) -> SRTConnectionQuality {
        let metrics = computeMetrics(from: statistics)

        let grade: Grade
        switch metrics.score {
        case 0.9...: grade = .excellent
        case 0.7..<0.9: grade = .good
        case 0.5..<0.7: grade = .fair
        case 0.3..<0.5: grade = .poor
        default: grade = .critical
        }

        let recommendation = QualityRecommendation.generate(from: metrics)

        return SRTConnectionQuality(
            score: metrics.score,
            grade: grade,
            rttScore: metrics.rttScore,
            lossScore: metrics.lossScore,
            bufferScore: metrics.bufferScore,
            bitrateEfficiencyScore: metrics.bitrateEff,
            stabilityScore: metrics.stabilityScore,
            recommendation: recommendation
        )
    }

    // MARK: - Private

    private static func computeMetrics(from statistics: SRTStatistics) -> QualityMetrics {
        let rttScore =
            statistics.rttMicroseconds > 0
            ? max(0, 1.0 - Double(statistics.rttMicroseconds) / 500_000.0)
            : 1.0

        let lossScore = max(0, 1.0 - statistics.lossRate / 0.10)

        let bufferScore: Double
        if statistics.sendBufferCapacity > 0 {
            let available = statistics.sendBufferCapacity - statistics.sendBufferPackets
            bufferScore = Double(available) / Double(statistics.sendBufferCapacity)
        } else {
            bufferScore = 0.5
        }

        let bitrateEff: Double
        if statistics.maxBandwidthBitsPerSecond > 0 {
            bitrateEff = min(
                Double(statistics.sendRateBitsPerSecond)
                    / Double(statistics.maxBandwidthBitsPerSecond), 1.0)
        } else {
            bitrateEff = 0.5
        }

        let stabilityScore: Double
        if statistics.rttMicroseconds > 0 {
            stabilityScore = max(
                0,
                1.0 - Double(statistics.rttVarianceMicroseconds)
                    / Double(statistics.rttMicroseconds))
        } else {
            stabilityScore = 1.0
        }

        let score =
            rttScore * rttWeight
            + lossScore * lossWeight
            + bufferScore * bufferWeight
            + bitrateEff * bitrateWeight
            + stabilityScore * stabilityWeight

        return QualityMetrics(
            score: score,
            statistics: statistics,
            rttScore: rttScore,
            lossScore: lossScore,
            stabilityScore: stabilityScore,
            bitrateEff: bitrateEff,
            bufferScore: bufferScore
        )
    }
}
