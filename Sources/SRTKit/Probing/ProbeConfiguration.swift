// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Configuration for bandwidth probing.
public struct ProbeConfiguration: Sendable, Equatable {
    /// Bitrate steps to probe (ascending order, bits/second).
    public let steps: [UInt64]

    /// Duration per step in microseconds (default: 1_000_000 = 1s).
    public let stepDurationMicroseconds: UInt64

    /// Loss rate threshold to detect saturation (default: 0.02 = 2%).
    public let lossThreshold: Double

    /// RTT increase ratio to detect saturation (default: 1.5 = 50% increase).
    public let rttIncreaseThreshold: Double

    /// Minimum steps to probe before allowing early stop (default: 2).
    public let minimumSteps: Int

    /// Create a probe configuration.
    ///
    /// - Parameters:
    ///   - steps: Bitrate steps in bits/second (ascending).
    ///   - stepDurationMicroseconds: Duration per step.
    ///   - lossThreshold: Loss rate threshold for saturation.
    ///   - rttIncreaseThreshold: RTT increase ratio for saturation.
    ///   - minimumSteps: Minimum steps before early stop.
    public init(
        steps: [UInt64] = [
            500_000, 1_000_000, 2_000_000, 4_000_000,
            8_000_000, 16_000_000, 32_000_000
        ],
        stepDurationMicroseconds: UInt64 = 1_000_000,
        lossThreshold: Double = 0.02,
        rttIncreaseThreshold: Double = 1.5,
        minimumSteps: Int = 2
    ) {
        self.steps = steps
        self.stepDurationMicroseconds = stepDurationMicroseconds
        self.lossThreshold = lossThreshold
        self.rttIncreaseThreshold = rttIncreaseThreshold
        self.minimumSteps = minimumSteps
    }

    /// Quick probe (3 steps, 500ms each).
    public static let quick = ProbeConfiguration(
        steps: [1_000_000, 4_000_000, 8_000_000],
        stepDurationMicroseconds: 500_000
    )

    /// Standard probe (7 steps, 1s each).
    public static let standard = ProbeConfiguration()

    /// Thorough probe (10 steps, 2s each, finer granularity).
    public static let thorough = ProbeConfiguration(
        steps: [
            250_000, 500_000, 1_000_000, 2_000_000, 4_000_000,
            6_000_000, 8_000_000, 12_000_000, 16_000_000, 32_000_000
        ],
        stepDurationMicroseconds: 2_000_000
    )
}
