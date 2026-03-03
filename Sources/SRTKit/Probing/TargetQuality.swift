// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Target quality level for auto-configuration.
public enum TargetQuality: String, Sendable, CaseIterable, CustomStringConvertible {
    /// Prioritize quality: use 60% of available bandwidth, higher latency.
    case quality

    /// Balance quality and latency: use 70% of available bandwidth.
    case balanced

    /// Prioritize low latency: use 80% of available bandwidth, minimal buffer.
    case lowLatency

    /// Bandwidth utilization factor (0.0–1.0).
    public var bandwidthFactor: Double {
        switch self {
        case .quality: return 0.6
        case .balanced: return 0.7
        case .lowLatency: return 0.8
        }
    }

    /// Latency multiplier relative to measured RTT.
    public var latencyMultiplier: Double {
        switch self {
        case .quality: return 6.0
        case .balanced: return 4.0
        case .lowLatency: return 2.5
        }
    }

    /// Human-readable description.
    public var description: String { rawValue }
}
