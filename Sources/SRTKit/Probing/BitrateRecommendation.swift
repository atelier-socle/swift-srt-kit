// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Real-time bitrate recommendation during active streaming.
///
/// Emitted by BitrateMonitor based on network condition analysis.
/// Consumers (encoders) can adjust bitrate accordingly.
public struct BitrateRecommendation: Sendable, Equatable {
    /// Recommended target bitrate in bits/second.
    public let recommendedBitrate: UInt64

    /// Current estimated send rate in bits/second.
    public let currentBitrate: UInt64

    /// Direction of change.
    public let direction: Direction

    /// Primary reason for the recommendation.
    public let reason: Reason

    /// Confidence level (0.0–1.0). Higher = more indicators agree.
    public let confidence: Double

    /// Create a bitrate recommendation.
    ///
    /// - Parameters:
    ///   - recommendedBitrate: Recommended target bitrate in bits/second.
    ///   - currentBitrate: Current send rate in bits/second.
    ///   - direction: Direction of bitrate change.
    ///   - reason: Primary reason for the recommendation.
    ///   - confidence: Confidence level (0.0–1.0).
    public init(
        recommendedBitrate: UInt64,
        currentBitrate: UInt64,
        direction: Direction,
        reason: Reason,
        confidence: Double
    ) {
        self.recommendedBitrate = recommendedBitrate
        self.currentBitrate = currentBitrate
        self.direction = direction
        self.reason = reason
        self.confidence = confidence
    }

    /// Direction of bitrate change.
    public enum Direction: String, Sendable, CaseIterable, Equatable {
        /// Increase bitrate — headroom available.
        case increase
        /// Decrease bitrate — congestion detected.
        case decrease
        /// Maintain current bitrate — stable conditions.
        case maintain
    }

    /// Reason for the recommendation.
    public enum Reason: String, Sendable, CaseIterable, Equatable {
        /// Send buffer is growing — congestion.
        case congestion
        /// Packet loss rate above threshold.
        case packetLoss
        /// RTT increasing trend.
        case rttIncrease
        /// Bandwidth headroom detected.
        case bandwidthAvailable
        /// Conditions are stable.
        case stable
    }
}
