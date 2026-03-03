// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Measurement data from a single probe step.
public struct StepMeasurement: Sendable, Equatable {
    /// Target bitrate for this step in bits/second.
    public let targetBitrate: UInt64

    /// Achieved send rate in bits/second.
    public let achievedSendRate: UInt64

    /// RTT at the end of this step in microseconds.
    public let rttMicroseconds: UInt64

    /// RTT variance at the end of this step.
    public let rttVarianceMicroseconds: UInt64

    /// Packet loss rate during this step (0.0–1.0).
    public let lossRate: Double

    /// Send buffer utilization (0.0–1.0).
    public let bufferUtilization: Double

    /// Whether this step detected saturation.
    public let saturated: Bool

    /// Step index.
    public let stepIndex: Int

    /// Create a step measurement.
    ///
    /// - Parameters:
    ///   - targetBitrate: Target bitrate in bits/second.
    ///   - achievedSendRate: Achieved send rate in bits/second.
    ///   - rttMicroseconds: RTT in microseconds.
    ///   - rttVarianceMicroseconds: RTT variance in microseconds.
    ///   - lossRate: Packet loss rate (0.0–1.0).
    ///   - bufferUtilization: Send buffer utilization (0.0–1.0).
    ///   - saturated: Whether saturation was detected.
    ///   - stepIndex: Step index.
    public init(
        targetBitrate: UInt64,
        achievedSendRate: UInt64,
        rttMicroseconds: UInt64,
        rttVarianceMicroseconds: UInt64,
        lossRate: Double,
        bufferUtilization: Double,
        saturated: Bool,
        stepIndex: Int
    ) {
        self.targetBitrate = targetBitrate
        self.achievedSendRate = achievedSendRate
        self.rttMicroseconds = rttMicroseconds
        self.rttVarianceMicroseconds = rttVarianceMicroseconds
        self.lossRate = lossRate
        self.bufferUtilization = bufferUtilization
        self.saturated = saturated
        self.stepIndex = stepIndex
    }
}
