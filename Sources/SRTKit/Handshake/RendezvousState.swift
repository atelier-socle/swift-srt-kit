// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// State of the rendezvous handshake state machine.
///
/// Tracks the progression of the three-phase rendezvous handshake
/// through waveahand, conclusion, and agreement phases.
public enum RendezvousState: String, Sendable, CaseIterable, CustomStringConvertible {
    /// Initial state before the handshake has started.
    case idle
    /// Sent WAVEAHAND, awaiting peer's WAVEAHAND.
    case waveahandSent
    /// Sent CONCLUSION with extensions, awaiting peer's CONCLUSION.
    case conclusionSent
    /// Sent AGREEMENT, awaiting peer's AGREEMENT.
    case agreementSent
    /// The handshake completed successfully.
    case done
    /// The handshake failed due to timeout, rejection, or error.
    case failed

    /// A human-readable description of the rendezvous state.
    public var description: String { rawValue }
}
