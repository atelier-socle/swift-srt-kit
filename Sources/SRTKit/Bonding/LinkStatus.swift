// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Status of a member link in a connection group.
public enum LinkStatus: String, Sendable, CaseIterable, CustomStringConvertible {
    /// Connection not established yet.
    case pending
    /// Connected, keepalive active, ready for activation.
    case idle
    /// Just activated, being qualified.
    case freshActivated
    /// Running, no issues detected.
    case stable
    /// Response timeout detected, backup activation triggered.
    case unstable
    /// Link failed.
    case broken

    /// Whether this link can carry data.
    public var isActive: Bool {
        switch self {
        case .freshActivated, .stable: true
        default: false
        }
    }

    /// Whether this link is in a terminal state.
    public var isTerminal: Bool {
        self == .broken
    }

    /// Valid transitions from this status.
    public var validTransitions: Set<LinkStatus> {
        switch self {
        case .pending: [.idle, .broken]
        case .idle: [.freshActivated, .broken]
        case .freshActivated: [.stable, .unstable, .broken]
        case .stable: [.unstable, .broken]
        case .unstable: [.stable, .broken]
        case .broken: []
        }
    }

    /// A human-readable description of this status.
    public var description: String {
        rawValue
    }
}
