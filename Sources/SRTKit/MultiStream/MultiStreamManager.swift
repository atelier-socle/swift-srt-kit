// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Manages multiple independent SRT streams over shared resources.
///
/// Each stream has independent buffers, encryption, and statistics.
/// Streams are isolated — failure of one does not affect others.
public struct MultiStreamManager: Sendable {
    /// Event from the multi-stream manager.
    public enum Event: Sendable {
        /// New stream created.
        case streamCreated(StreamInfo)
        /// Stream removed.
        case streamRemoved(id: UInt32)
        /// Stream error (isolated to that stream).
        case streamError(id: UInt32, reason: String)
    }

    /// Maximum number of concurrent streams.
    public let maxStreams: Int

    private var streamList: [StreamInfo] = []

    /// Create a multi-stream manager.
    ///
    /// - Parameter maxStreams: Maximum concurrent streams (default: 16).
    public init(maxStreams: Int = 16) {
        self.maxStreams = maxStreams
    }

    /// Add a new stream.
    ///
    /// - Parameter info: Stream information.
    /// - Throws: `MultiStreamError` if at capacity or duplicate ID.
    public mutating func addStream(_ info: StreamInfo) throws {
        if streamList.contains(where: { $0.id == info.id }) {
            throw MultiStreamError.duplicateStream(id: info.id)
        }
        if streamList.count >= maxStreams {
            throw MultiStreamError.maxStreamsReached(max: maxStreams)
        }
        streamList.append(info)
    }

    /// Remove a stream.
    ///
    /// - Parameter id: Stream ID to remove.
    public mutating func removeStream(id: UInt32) {
        streamList.removeAll { $0.id == id }
    }

    /// Get all active streams.
    public var streams: [StreamInfo] {
        streamList
    }

    /// Get a specific stream.
    ///
    /// - Parameter id: Stream ID.
    /// - Returns: Stream info, or nil if not found.
    public func stream(id: UInt32) -> StreamInfo? {
        streamList.first { $0.id == id }
    }

    /// Number of active streams.
    public var activeCount: Int {
        streamList.count
    }

    /// Check if at capacity.
    public var isFull: Bool {
        streamList.count >= maxStreams
    }

    /// Route an incoming packet to the correct stream by socket ID.
    ///
    /// - Parameter destinationSocketID: Socket ID from the packet header.
    /// - Returns: Stream ID that should handle this packet, or nil.
    public func routePacket(destinationSocketID: UInt32) -> UInt32? {
        streamList.first { $0.socketID == destinationSocketID }?.id
    }
}
