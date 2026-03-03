// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Configuration for the adaptive bitrate monitor.
public struct BitrateMonitorConfiguration: Sendable, Equatable {
    /// How many consecutive signals in the same direction before
    /// emitting a recommendation (default: 3).
    public let hysteresisCount: Int

    /// Loss rate threshold to trigger decrease (default: 0.02 = 2%).
    public let lossThreshold: Double

    /// RTT increase ratio to trigger decrease (default: 1.3 = 30% increase).
    public let rttIncreaseRatio: Double

    /// Buffer utilization threshold to trigger decrease (default: 0.7 = 70%).
    public let bufferThreshold: Double

    /// Bandwidth headroom ratio to allow increase (default: 0.7 = using < 70% of max).
    public let headroomRatio: Double

    /// Step-down factor when decreasing (default: 0.75 = reduce 25%).
    public let stepDownFactor: Double

    /// Step-up factor when increasing (default: 1.10 = increase 10%).
    public let stepUpFactor: Double

    /// Minimum bitrate floor in bits/second (default: 100_000 = 100kbps).
    public let minimumBitrate: UInt64

    /// Maximum bitrate ceiling in bits/second (default: 0 = no limit).
    public let maximumBitrate: UInt64

    /// Create a bitrate monitor configuration.
    ///
    /// - Parameters:
    ///   - hysteresisCount: Consecutive signals before emitting.
    ///   - lossThreshold: Loss rate threshold for decrease.
    ///   - rttIncreaseRatio: RTT increase ratio for decrease.
    ///   - bufferThreshold: Buffer utilization threshold for decrease.
    ///   - headroomRatio: Bandwidth headroom ratio for increase.
    ///   - stepDownFactor: Factor for decreasing bitrate.
    ///   - stepUpFactor: Factor for increasing bitrate.
    ///   - minimumBitrate: Minimum bitrate floor.
    ///   - maximumBitrate: Maximum bitrate ceiling (0 = no limit).
    public init(
        hysteresisCount: Int = 3,
        lossThreshold: Double = 0.02,
        rttIncreaseRatio: Double = 1.3,
        bufferThreshold: Double = 0.7,
        headroomRatio: Double = 0.7,
        stepDownFactor: Double = 0.75,
        stepUpFactor: Double = 1.10,
        minimumBitrate: UInt64 = 100_000,
        maximumBitrate: UInt64 = 0
    ) {
        self.hysteresisCount = hysteresisCount
        self.lossThreshold = lossThreshold
        self.rttIncreaseRatio = rttIncreaseRatio
        self.bufferThreshold = bufferThreshold
        self.headroomRatio = headroomRatio
        self.stepDownFactor = stepDownFactor
        self.stepUpFactor = stepUpFactor
        self.minimumBitrate = minimumBitrate
        self.maximumBitrate = maximumBitrate
    }

    /// Conservative: slow to change, high hysteresis.
    public static let conservative = BitrateMonitorConfiguration(
        hysteresisCount: 5,
        lossThreshold: 0.03,
        rttIncreaseRatio: 1.5,
        bufferThreshold: 0.8,
        stepDownFactor: 0.85,
        stepUpFactor: 1.05
    )

    /// Responsive: faster reaction to changes.
    public static let responsive = BitrateMonitorConfiguration(
        hysteresisCount: 2,
        lossThreshold: 0.015,
        rttIncreaseRatio: 1.2,
        bufferThreshold: 0.6,
        stepDownFactor: 0.70,
        stepUpFactor: 1.15
    )

    /// Aggressive: immediate reaction.
    public static let aggressive = BitrateMonitorConfiguration(
        hysteresisCount: 1,
        lossThreshold: 0.01,
        rttIncreaseRatio: 1.1,
        bufferThreshold: 0.5,
        stepDownFactor: 0.60,
        stepUpFactor: 1.20
    )
}
