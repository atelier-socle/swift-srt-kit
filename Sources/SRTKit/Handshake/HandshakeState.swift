// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// State of the handshake state machine.
///
/// Tracks the progression of the SRT handshake through induction and conclusion phases.
public enum HandshakeState: String, Sendable, CaseIterable, CustomStringConvertible {
    /// Initial state before the handshake has started.
    case idle
    /// Caller has sent the induction packet and is awaiting a response.
    case inductionSent
    /// Listener has received the induction and sent a response.
    case inductionReceived
    /// Caller has sent the conclusion packet and is awaiting a response.
    case conclusionSent
    /// Listener has received the conclusion and is processing it.
    case conclusionReceived
    /// The handshake completed successfully and a connection is established.
    case done
    /// The handshake failed due to timeout, rejection, or error.
    case failed

    /// A human-readable description of the handshake state.
    public var description: String { rawValue }
}
