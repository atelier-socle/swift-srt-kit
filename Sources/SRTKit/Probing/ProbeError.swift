// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Errors from the probing subsystem.
public enum ProbeError: Error, Sendable, Equatable, CustomStringConvertible {
    /// Probe already in progress.
    case probeInProgress

    /// No steps configured.
    case noSteps

    /// Probe not started.
    case probeNotStarted

    /// All steps saturated immediately.
    case immediatelySaturated

    /// Human-readable description.
    public var description: String {
        switch self {
        case .probeInProgress:
            return "Probe already in progress"
        case .noSteps:
            return "No steps configured"
        case .probeNotStarted:
            return "Probe not started"
        case .immediatelySaturated:
            return "All steps saturated immediately"
        }
    }
}
