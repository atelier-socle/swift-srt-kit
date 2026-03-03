// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Result of a bandwidth probe.
public struct ProbeResult: Sendable, Equatable {
    /// Maximum achieved bandwidth before saturation in bits/second.
    public let achievedBandwidth: UInt64

    /// Average RTT during probe in microseconds.
    public let averageRTTMicroseconds: UInt64

    /// RTT variance during probe in microseconds.
    public let rttVarianceMicroseconds: UInt64

    /// Packet loss rate observed (0.0–1.0).
    public let packetLossRate: Double

    /// Stability score (0–100). High = consistent performance.
    public let stabilityScore: Int

    /// Recommended bitrate for streaming in bits/second.
    public let recommendedBitrate: UInt64

    /// Recommended TSBPD latency in microseconds.
    public let recommendedLatency: UInt64

    /// Number of steps completed.
    public let stepsCompleted: Int

    /// Total probe duration in microseconds.
    public let totalDurationMicroseconds: UInt64

    /// Step at which saturation was detected (nil if no saturation).
    public let saturationStepIndex: Int?

    /// Create a probe result.
    ///
    /// - Parameters:
    ///   - achievedBandwidth: Maximum achieved bandwidth in bits/second.
    ///   - averageRTTMicroseconds: Average RTT in microseconds.
    ///   - rttVarianceMicroseconds: RTT variance in microseconds.
    ///   - packetLossRate: Packet loss rate (0.0–1.0).
    ///   - stabilityScore: Stability score (0–100).
    ///   - recommendedBitrate: Recommended bitrate in bits/second.
    ///   - recommendedLatency: Recommended TSBPD latency in microseconds.
    ///   - stepsCompleted: Number of steps completed.
    ///   - totalDurationMicroseconds: Total probe duration in microseconds.
    ///   - saturationStepIndex: Step at which saturation was detected.
    public init(
        achievedBandwidth: UInt64,
        averageRTTMicroseconds: UInt64,
        rttVarianceMicroseconds: UInt64,
        packetLossRate: Double,
        stabilityScore: Int,
        recommendedBitrate: UInt64,
        recommendedLatency: UInt64,
        stepsCompleted: Int,
        totalDurationMicroseconds: UInt64,
        saturationStepIndex: Int?
    ) {
        self.achievedBandwidth = achievedBandwidth
        self.averageRTTMicroseconds = averageRTTMicroseconds
        self.rttVarianceMicroseconds = rttVarianceMicroseconds
        self.packetLossRate = packetLossRate
        self.stabilityScore = stabilityScore
        self.recommendedBitrate = recommendedBitrate
        self.recommendedLatency = recommendedLatency
        self.stepsCompleted = stepsCompleted
        self.totalDurationMicroseconds = totalDurationMicroseconds
        self.saturationStepIndex = saturationStepIndex
    }
}
