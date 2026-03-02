// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// The state of an SRT socket throughout its lifecycle.
///
/// Transitions follow the SRT protocol state machine:
/// `idle` -> `opening`/`listening`/`connecting` -> `connected` -> `closing` -> `closed`
/// Any state may transition to `broken` on unrecoverable error.
public enum SRTSocketState: String, Sendable, CaseIterable, Hashable, CustomStringConvertible {
    /// Socket is created but not yet configured.
    case idle
    /// Socket is performing initial setup.
    case opening
    /// Socket is listening for incoming connections.
    case listening
    /// Socket is attempting to connect to a remote peer.
    case connecting
    /// Socket is fully connected and ready for data transfer.
    case connected
    /// Socket connection is broken due to an unrecoverable error.
    case broken
    /// Socket is gracefully shutting down.
    case closing
    /// Socket is fully closed and resources are released.
    case closed

    /// A human-readable description of the socket state.
    public var description: String {
        rawValue
    }
}
