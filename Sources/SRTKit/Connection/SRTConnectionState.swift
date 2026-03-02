// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// State machine for an SRT connection.
public enum SRTConnectionState: String, Sendable, CaseIterable, CustomStringConvertible {
    /// Initial state, not connected.
    case idle
    /// Connection initiation in progress (caller: sending handshake).
    case connecting
    /// Handshake exchange in progress.
    case handshaking
    /// Handshake complete, ready for data transfer.
    case connected
    /// Actively transferring data.
    case transferring
    /// Graceful shutdown initiated.
    case closing
    /// Connection fully closed.
    case closed
    /// Connection broken (timeout, error).
    case broken

    /// Whether the connection can send/receive data.
    public var isActive: Bool { self == .connected || self == .transferring }

    /// Whether the connection is in a terminal state.
    public var isTerminal: Bool { self == .closed || self == .broken }

    /// Valid transitions from this state.
    public var validTransitions: Set<SRTConnectionState> {
        switch self {
        case .idle:
            return [.connecting]
        case .connecting:
            return [.handshaking, .broken, .closed]
        case .handshaking:
            return [.connected, .broken, .closed]
        case .connected:
            return [.transferring, .closing, .broken]
        case .transferring:
            return [.closing, .broken]
        case .closing:
            return [.closed, .broken]
        case .closed, .broken:
            return []
        }
    }

    /// Human-readable description.
    public var description: String { rawValue }
}
