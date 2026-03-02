// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Manages too-late packet dropping on the receiver side.
///
/// In live mode, packets that arrive past their delivery deadline
/// are dropped to prevent unbounded buffering and maintain live
/// playback. This component tracks drops and generates DROPREQ
/// notifications for the sender.
public struct TooLatePacketDrop: Sendable {
    /// Result of checking a packet for too-late drop.
    public enum DropDecision: Sendable, Equatable {
        /// Packet is on time — keep it.
        case keep
        /// Packet is too late — drop it.
        case drop(lateness: UInt64)
    }

    /// A range of dropped packets for DROPREQ notification.
    public struct DropRange: Sendable, Equatable {
        /// The first sequence number in the dropped range.
        public let firstSequence: SequenceNumber
        /// The last sequence number in the dropped range.
        public let lastSequence: SequenceNumber
        /// The message number associated with the dropped range.
        public let messageNumber: UInt32
    }

    /// Whether too-late drop is enabled.
    public let enabled: Bool

    /// Total number of packets dropped as too late.
    public private(set) var totalDropped: Int = 0

    /// Total number of drop events (each may cover a range).
    public private(set) var dropEventCount: Int = 0

    /// Creates a too-late packet drop manager.
    ///
    /// - Parameter enabled: Whether too-late drop is enabled.
    public init(enabled: Bool = true) {
        self.enabled = enabled
    }

    /// Check if a packet should be dropped.
    ///
    /// - Parameters:
    ///   - deliveryTime: Calculated delivery time for this packet (µs).
    ///   - currentTime: Current local time (µs).
    /// - Returns: Drop decision.
    public func check(deliveryTime: UInt64, currentTime: UInt64) -> DropDecision {
        guard enabled else { return .keep }
        guard currentTime > deliveryTime else { return .keep }
        let lateness = currentTime - deliveryTime
        return .drop(lateness: lateness)
    }

    /// Record a dropped packet range.
    ///
    /// - Parameters:
    ///   - firstSequence: First sequence number in the range.
    ///   - lastSequence: Last sequence number in the range.
    ///   - messageNumber: Message number for the drop.
    /// - Returns: A DropRange for DROPREQ notification.
    public mutating func recordDrop(
        firstSequence: SequenceNumber,
        lastSequence: SequenceNumber,
        messageNumber: UInt32
    ) -> DropRange {
        // Count packets in range using signed distance
        let dist = SequenceNumber.distance(from: firstSequence, to: lastSequence)
        let packetCount = Int(dist) + 1
        totalDropped += packetCount
        dropEventCount += 1
        return DropRange(
            firstSequence: firstSequence,
            lastSequence: lastSequence,
            messageNumber: messageNumber
        )
    }

    /// Reset statistics.
    public mutating func resetStatistics() {
        totalDropped = 0
        dropEventCount = 0
    }
}
