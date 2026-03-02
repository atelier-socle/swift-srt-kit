// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Broadcast bonding logic.
///
/// Sends packets on all active links. Receiver deduplicates
/// by sequence number (keeps first arrival).
public struct BroadcastStrategy: Sendable {
    /// Result of submitting a packet for broadcast.
    public struct BroadcastResult: Sendable {
        /// Members to send the packet to.
        public let targets: [UInt32]
        /// Sequence number assigned to the packet.
        public let sequenceNumber: SequenceNumber
    }

    /// Result of receiving a packet.
    public enum ReceiveResult: Sendable {
        /// New packet (first arrival for this sequence number).
        case newPacket(payload: [UInt8], sequenceNumber: SequenceNumber)
        /// Duplicate (already received on another link).
        case duplicate(sequenceNumber: SequenceNumber)
    }

    /// Current group sequence number.
    public var groupSequence: SequenceNumber

    /// Deduplicator for received packets.
    private var deduplicator: PacketDeduplicator

    /// Creates a broadcast strategy.
    ///
    /// - Parameter initialSequence: Initial sequence number.
    public init(initialSequence: SequenceNumber = SequenceNumber(0)) {
        self.groupSequence = initialSequence
        self.deduplicator = PacketDeduplicator()
    }

    /// Prepare a packet for broadcast on all active members.
    ///
    /// - Parameter activeMembers: Currently active member IDs.
    /// - Returns: Broadcast targets and assigned sequence number.
    public mutating func prepareSend(
        activeMembers: [UInt32]
    ) -> BroadcastResult {
        let seq = groupSequence
        groupSequence += 1
        return BroadcastResult(
            targets: activeMembers,
            sequenceNumber: seq
        )
    }

    /// Process a received packet (deduplication).
    ///
    /// - Parameters:
    ///   - sequenceNumber: The packet's sequence number.
    ///   - payload: The packet payload.
    ///   - fromMember: Source member ID.
    /// - Returns: New packet or duplicate.
    public mutating func processReceive(
        sequenceNumber: SequenceNumber,
        payload: [UInt8],
        fromMember: UInt32
    ) -> ReceiveResult {
        if deduplicator.isNew(sequenceNumber) {
            return .newPacket(payload: payload, sequenceNumber: sequenceNumber)
        }
        return .duplicate(sequenceNumber: sequenceNumber)
    }

    /// Number of duplicates suppressed.
    public var duplicatesSuppressed: Int {
        deduplicator.duplicatesDetected
    }

    /// Reset state.
    public mutating func reset() {
        deduplicator.reset()
    }
}
