// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Information about an independent stream within a multiplexed context.
public struct StreamInfo: Sendable, Identifiable, Equatable {
    /// Unique stream identifier.
    public let id: UInt32

    /// Socket ID for this stream.
    public let socketID: UInt32

    /// Peer socket ID.
    public var peerSocketID: UInt32?

    /// StreamID / access control.
    public let streamID: String?

    /// Whether this stream has its own encryption.
    public let encrypted: Bool

    /// Stream creation time in microseconds.
    public let creationTime: UInt64

    /// Create stream info.
    ///
    /// - Parameters:
    ///   - id: Unique stream identifier.
    ///   - socketID: Socket ID for this stream.
    ///   - streamID: Optional StreamID for access control.
    ///   - encrypted: Whether encryption is enabled.
    ///   - creationTime: Creation time in microseconds.
    public init(
        id: UInt32,
        socketID: UInt32,
        streamID: String? = nil,
        encrypted: Bool = false,
        creationTime: UInt64 = 0
    ) {
        self.id = id
        self.socketID = socketID
        self.peerSocketID = nil
        self.streamID = streamID
        self.encrypted = encrypted
        self.creationTime = creationTime
    }
}
