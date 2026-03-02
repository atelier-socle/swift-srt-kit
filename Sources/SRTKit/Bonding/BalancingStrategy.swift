// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Balancing bonding logic.
///
/// Distributes packets across links for bandwidth aggregation.
/// Uses message numbers for cross-link ordering and weight x
/// bandwidth / load scoring for link selection.
public struct BalancingStrategy: Sendable {
    /// Result of selecting a link for a packet.
    public struct LinkSelection: Sendable {
        /// Selected member ID.
        public let memberID: UInt32
        /// Message number assigned.
        public let messageNumber: UInt32
        /// Selection score.
        public let score: UInt64
    }

    /// Current global message number.
    public var currentMessageNumber: UInt32

    /// Per-member packet distribution counts.
    private var distribution: [UInt32: Int] = [:]

    /// Next expected message number for receive reordering.
    private var nextExpectedMessage: UInt32 = 0

    /// Buffered out-of-order received packets.
    private var receiveBuffer: [UInt32: [UInt8]] = [:]

    /// Creates a balancing strategy.
    ///
    /// - Parameter initialMessageNumber: Initial global message number.
    public init(initialMessageNumber: UInt32 = 0) {
        self.currentMessageNumber = initialMessageNumber
        self.nextExpectedMessage = initialMessageNumber
    }

    /// Select the best link for the next packet.
    ///
    /// Score = weight x estimatedBandwidth / max(currentLoad, 1).
    /// Selects the link with the highest score.
    /// - Parameter activeMembers: Currently active members with metrics.
    /// - Returns: Selected link and assigned message number.
    public mutating func selectLink(
        from activeMembers: [GroupMember]
    ) -> LinkSelection? {
        guard !activeMembers.isEmpty else { return nil }

        var bestMember: GroupMember?
        var bestScore: UInt64 = 0

        for member in activeMembers {
            let score =
                UInt64(member.weight) * member.estimatedBandwidth
                / UInt64(max(member.currentLoad, 1))
            if score > bestScore || bestMember == nil {
                bestScore = score
                bestMember = member
            }
        }

        guard let selected = bestMember else { return nil }

        let msgNum = currentMessageNumber
        currentMessageNumber &+= 1
        distribution[selected.id, default: 0] += 1

        return LinkSelection(
            memberID: selected.id,
            messageNumber: msgNum,
            score: bestScore
        )
    }

    /// Record that a packet was delivered on a link.
    ///
    /// - Parameter memberID: Member that delivered the packet.
    public mutating func recordDelivery(memberID: UInt32) {
        distribution[memberID, default: 0] += 1
    }

    /// Process received packets from multiple links.
    ///
    /// Reorders by message number before delivery.
    /// - Parameters:
    ///   - messageNumber: The message number.
    ///   - payload: The packet payload.
    ///   - fromMember: Source member ID.
    /// - Returns: Ordered payloads ready for delivery.
    public mutating func processReceive(
        messageNumber: UInt32,
        payload: [UInt8],
        fromMember: UInt32
    ) -> [[UInt8]] {
        if messageNumber == nextExpectedMessage {
            var delivered: [[UInt8]] = [payload]
            nextExpectedMessage &+= 1

            // Deliver any buffered consecutive messages
            while let buffered = receiveBuffer.removeValue(
                forKey: nextExpectedMessage)
            {
                delivered.append(buffered)
                nextExpectedMessage &+= 1
            }

            return delivered
        }

        // Out of order — buffer it
        receiveBuffer[messageNumber] = payload
        return []
    }

    /// Distribution statistics per member.
    public var distributionStats: [UInt32: Int] {
        distribution
    }

    /// Reset state.
    public mutating func reset() {
        distribution.removeAll()
        receiveBuffer.removeAll()
        nextExpectedMessage = currentMessageNumber
    }
}
