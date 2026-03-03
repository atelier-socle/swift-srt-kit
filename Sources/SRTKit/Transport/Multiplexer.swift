// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore

/// Dispatches incoming SRT packets to their target connection.
///
/// The multiplexer operates in two modes:
/// 1. **Pre-handshake**: Routes by source address (peer IP + port)
/// 2. **Post-handshake**: Routes by Destination Socket ID in the SRT header
///
/// Multiple SRT connections share a single UDP port through the multiplexer.
public actor Multiplexer {
    /// A registered connection that can receive packets.
    public struct Registration: Sendable {
        /// The local SRT Socket ID for this connection.
        public let socketID: UInt32
        /// Optional initial remote address for pre-handshake routing.
        public let remoteAddress: SocketAddress?
        /// The stream continuation to deliver packets to.
        public let continuation: AsyncStream<IncomingDatagram>.Continuation
    }

    /// Registrations keyed by socket ID.
    private var registrations: [UInt32: Registration] = [:]
    /// Reverse lookup: remote address → socket ID for pre-handshake routing.
    private var addressMap: [SocketAddress: UInt32] = [:]

    /// Creates a new multiplexer.
    public init() {}

    /// Register a connection to receive packets for a specific Socket ID.
    ///
    /// - Parameters:
    ///   - socketID: The local SRT Socket ID for this connection.
    ///   - remoteAddress: Optional initial remote address.
    /// - Returns: AsyncStream of datagrams for this connection.
    public func register(
        socketID: UInt32,
        remoteAddress: SocketAddress? = nil
    ) -> AsyncStream<IncomingDatagram> {
        let (stream, continuation) = AsyncStream<IncomingDatagram>.makeStream()
        let registration = Registration(
            socketID: socketID,
            remoteAddress: remoteAddress,
            continuation: continuation
        )
        registrations[socketID] = registration
        if let addr = remoteAddress {
            addressMap[addr] = socketID
        }
        return stream
    }

    /// Unregister a connection. Stops delivering packets to it.
    ///
    /// Safe to call with a non-existent socket ID (idempotent).
    /// - Parameter socketID: The socket ID to unregister.
    public func unregister(socketID: UInt32) {
        if let reg = registrations.removeValue(forKey: socketID) {
            reg.continuation.finish()
            if let addr = reg.remoteAddress {
                addressMap.removeValue(forKey: addr)
            }
        }
    }

    /// Dispatch an incoming datagram to the correct connection.
    ///
    /// Reads the Destination Socket ID from the SRT header (bytes 12–15,
    /// big-endian) and routes to the registered connection. If the Socket ID
    /// is 0 (pre-handshake), routes by source address instead.
    /// - Parameter datagram: The incoming datagram to dispatch.
    public func dispatch(_ datagram: IncomingDatagram) {
        let destSocketID = extractDestinationSocketID(from: datagram.data)

        if destSocketID != 0 {
            if let reg = registrations[destSocketID] {
                reg.continuation.yield(datagram)
            }
            return
        }

        // Pre-handshake: route by source address
        if let socketID = addressMap[datagram.remoteAddress],
            let reg = registrations[socketID]
        {
            reg.continuation.yield(datagram)
        }
    }

    /// Number of currently registered connections.
    public var connectionCount: Int {
        registrations.count
    }

    /// All registered socket IDs.
    public var registeredSocketIDs: Set<UInt32> {
        Set(registrations.keys)
    }

    /// Whether a registration exists for the given socket ID.
    ///
    /// - Parameter socketID: The socket ID to check.
    /// - Returns: True if a connection is registered for this socket ID.
    public func hasRegistration(for socketID: UInt32) -> Bool {
        registrations[socketID] != nil
    }

    // MARK: - Private

    /// Extracts the Destination Socket ID from bytes 12–15 of an SRT packet.
    ///
    /// The SRT header places the Destination Socket ID at a fixed offset:
    /// - Control packets: bytes 12–15
    /// - Data packets: bytes 12–15
    private func extractDestinationSocketID(from buffer: ByteBuffer) -> UInt32 {
        guard buffer.readableBytes >= 16 else { return 0 }
        let index = buffer.readerIndex + 12
        return buffer.getInteger(at: index, as: UInt32.self) ?? 0
    }
}
