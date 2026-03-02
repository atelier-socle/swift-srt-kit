// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore

/// A logical per-connection channel over a shared ``UDPTransport``.
///
/// Each SRT connection gets its own UDPChannel, which provides
/// send/receive operations scoped to a specific peer. The UDPChannel
/// uses the shared transport for actual I/O and the multiplexer for
/// packet routing.
public actor UDPChannel {
    /// Channel state.
    public enum State: String, Sendable {
        /// Channel created but not yet open.
        case idle
        /// Channel open and registered with the multiplexer.
        case open
        /// Channel closed and unregistered.
        case closed
    }

    /// The local Socket ID for this connection.
    public let socketID: UInt32
    /// The current channel state.
    public private(set) var state: State
    /// The remote peer address.
    public private(set) var remoteAddress: SocketAddress?

    private let transport: UDPTransport
    private let multiplexer: Multiplexer

    /// Create a channel for a specific connection.
    ///
    /// - Parameters:
    ///   - socketID: Local Socket ID for this connection.
    ///   - transport: Shared UDP transport for I/O.
    ///   - multiplexer: Shared multiplexer for packet routing.
    ///   - remoteAddress: Optional initial remote address.
    public init(
        socketID: UInt32,
        transport: UDPTransport,
        multiplexer: Multiplexer,
        remoteAddress: SocketAddress? = nil
    ) {
        self.socketID = socketID
        self.transport = transport
        self.multiplexer = multiplexer
        self.remoteAddress = remoteAddress
        self.state = .idle
    }

    /// Open the channel and start receiving packets.
    ///
    /// Registers with the multiplexer and transitions to `.open`.
    /// - Returns: AsyncStream of incoming datagrams for this connection.
    public func open() async -> AsyncStream<IncomingDatagram> {
        guard state == .idle else {
            let (stream, continuation) = AsyncStream<IncomingDatagram>.makeStream()
            continuation.finish()
            return stream
        }
        let stream = await multiplexer.register(
            socketID: socketID,
            remoteAddress: remoteAddress
        )
        state = .open
        return stream
    }

    /// Send a ByteBuffer to the remote peer.
    ///
    /// - Parameter buffer: The data to send.
    /// - Throws: ``SRTError`` if the channel is not open or no remote address is set.
    public func send(_ buffer: ByteBuffer) async throws {
        guard state == .open else {
            throw SRTError.connectionFailed("Cannot send: channel not open")
        }
        guard let remoteAddress else {
            throw SRTError.connectionFailed("Cannot send: no remote address")
        }
        try await transport.send(buffer, to: remoteAddress)
    }

    /// Update the remote address.
    ///
    /// Used after handshake resolves the actual peer address.
    /// - Parameter address: The new remote address.
    public func setRemoteAddress(_ address: SocketAddress) {
        self.remoteAddress = address
    }

    /// Close the channel and unregister from the multiplexer.
    ///
    /// Safe to call multiple times (idempotent).
    public func close() async {
        guard state != .closed else { return }
        await multiplexer.unregister(socketID: socketID)
        state = .closed
    }
}
