// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Negotiates TSBPD latency between caller and listener.
///
/// The negotiated latency for each direction is the maximum of both sides' values.
/// This ensures both the sender and receiver can handle the delay. The sender's
/// delay must satisfy the receiver's requirement, and vice versa.
public enum LatencyNegotiator: Sendable {
    /// Negotiates latency from local and remote TSBPD delay values.
    ///
    /// The sender delay is `max(localSenderDelay, remoteReceiverDelay)` because
    /// the sender must satisfy the remote receiver's latency requirement.
    /// The receiver delay is `max(localReceiverDelay, remoteSenderDelay)` because
    /// the receiver must satisfy the remote sender's latency requirement.
    ///
    /// - Parameters:
    ///   - localSenderDelay: The local sender's desired TSBPD delay in milliseconds.
    ///   - localReceiverDelay: The local receiver's desired TSBPD delay in milliseconds.
    ///   - remoteSenderDelay: The remote sender's declared TSBPD delay in milliseconds.
    ///   - remoteReceiverDelay: The remote receiver's declared TSBPD delay in milliseconds.
    /// - Returns: A tuple of negotiated `(senderDelay, receiverDelay)` in milliseconds.
    public static func negotiate(
        localSenderDelay: UInt16,
        localReceiverDelay: UInt16,
        remoteSenderDelay: UInt16,
        remoteReceiverDelay: UInt16
    ) -> (senderDelay: UInt16, receiverDelay: UInt16) {
        let senderDelay = max(localSenderDelay, remoteReceiverDelay)
        let receiverDelay = max(localReceiverDelay, remoteSenderDelay)
        return (senderDelay: senderDelay, receiverDelay: receiverDelay)
    }
}
