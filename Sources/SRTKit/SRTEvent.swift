// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Events emitted by an SRT socket during its lifecycle.
///
/// Events are delivered via `AsyncStream<SRTEvent>` and cover
/// state changes, connectivity, data reception, and diagnostics.
public enum SRTEvent: Sendable {
    /// The socket state changed.
    /// - Parameter state: The new socket state.
    case stateChanged(SRTSocketState)

    /// The socket successfully connected to a remote peer.
    /// - Parameter socketID: The destination socket identifier.
    case connected(socketID: UInt32)

    /// The socket disconnected from the remote peer.
    /// - Parameter reason: An optional reason for disconnection.
    case disconnected(reason: String?)

    /// An error occurred on the socket.
    /// - Parameter error: The error that occurred.
    case error(SRTError)

    /// Data was received from the remote peer.
    /// - Parameter data: The received payload bytes.
    case dataReceived([UInt8])

    /// Updated statistics are available.
    case statisticsUpdated
}
