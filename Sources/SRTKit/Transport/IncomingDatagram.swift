// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore

/// An incoming UDP datagram with its source address.
///
/// Represents a single UDP packet received by the transport layer,
/// paired with the remote address it was sent from.
public struct IncomingDatagram: Sendable {
    /// The raw datagram payload.
    public let data: ByteBuffer
    /// The source address of the datagram.
    public let remoteAddress: SocketAddress

    /// Creates an incoming datagram.
    ///
    /// - Parameters:
    ///   - data: The raw datagram payload.
    ///   - remoteAddress: The source address.
    public init(data: ByteBuffer, remoteAddress: SocketAddress) {
        self.data = data
        self.remoteAddress = remoteAddress
    }
}
