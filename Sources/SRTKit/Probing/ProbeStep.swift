// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A single step in a bandwidth probe ramp.
public struct ProbeStep: Sendable, Equatable {
    /// Target bitrate for this step in bits/second.
    public let targetBitrate: UInt64

    /// Duration of this step in microseconds.
    public let durationMicroseconds: UInt64

    /// Step index (0-based).
    public let index: Int

    /// Create a probe step.
    ///
    /// - Parameters:
    ///   - targetBitrate: Target bitrate in bits/second.
    ///   - durationMicroseconds: Duration in microseconds.
    ///   - index: Step index (0-based).
    public init(targetBitrate: UInt64, durationMicroseconds: UInt64, index: Int) {
        self.targetBitrate = targetBitrate
        self.durationMicroseconds = durationMicroseconds
        self.index = index
    }
}
