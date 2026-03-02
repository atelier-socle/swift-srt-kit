// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Reorder buffer that delivers received packets in sequence order.
///
/// Handles out-of-order arrival, duplicate detection, and gap tracking.
/// When a packet arrives, the buffer determines whether it can be
/// delivered immediately or must be held until missing predecessors arrive.
public struct ReceiveBuffer: Sendable {
    /// Result of inserting a packet into the receive buffer.
    public enum InsertResult: Sendable, Equatable {
        /// Packet is the next expected and can be delivered.
        /// `packets` includes this packet plus any consecutive buffered packets.
        case deliverable(packets: [ReceivedPacket])
        /// Packet is ahead of expected — buffered, gap detected.
        case buffered
        /// Packet is a duplicate — discarded.
        case duplicate
        /// Packet is too old (behind the ACK frontier) — discarded.
        case tooOld
    }

    /// A received packet.
    public struct ReceivedPacket: Sendable, Equatable {
        /// The packet's sequence number.
        public let sequenceNumber: SequenceNumber
        /// The raw packet payload.
        public let payload: [UInt8]
        /// The packet timestamp.
        public let timestamp: UInt32
        /// The message number.
        public let messageNumber: UInt32

        /// Creates a new received packet.
        ///
        /// - Parameters:
        ///   - sequenceNumber: The packet's sequence number.
        ///   - payload: The raw packet payload.
        ///   - timestamp: The packet timestamp.
        ///   - messageNumber: The message number.
        public init(
            sequenceNumber: SequenceNumber,
            payload: [UInt8],
            timestamp: UInt32 = 0,
            messageNumber: UInt32 = 0
        ) {
            self.sequenceNumber = sequenceNumber
            self.payload = payload
            self.timestamp = timestamp
            self.messageNumber = messageNumber
        }
    }

    /// The next expected sequence number (= last delivered + 1).
    public private(set) var nextExpected: SequenceNumber

    /// Out-of-order packets waiting for gaps to fill.
    private var buffered: [SequenceNumber: ReceivedPacket] = [:]

    /// The highest sequence number received so far.
    private var highestReceived: SequenceNumber?

    /// Create a receive buffer.
    ///
    /// - Parameter initialSequenceNumber: The first expected sequence number.
    public init(initialSequenceNumber: SequenceNumber) {
        self.nextExpected = initialSequenceNumber
    }

    /// Insert a received packet.
    ///
    /// - Parameter packet: The received packet to insert.
    /// - Returns: The insert result indicating what happened.
    public mutating func insert(_ packet: ReceivedPacket) -> InsertResult {
        let dist = SequenceNumber.distance(from: nextExpected, to: packet.sequenceNumber)

        // Behind the frontier — too old or duplicate
        if dist < 0 {
            return .tooOld
        }

        // Already buffered — duplicate
        if dist > 0, buffered[packet.sequenceNumber] != nil {
            return .duplicate
        }

        // Duplicate of next expected (dist == 0 already handled below if re-inserted)
        if dist == 0 {
            // Deliver this packet and any consecutive buffered ones
            return deliverChain(startingWith: packet)
        }

        // Ahead of expected — buffer it
        buffered[packet.sequenceNumber] = packet
        updateHighestReceived(packet.sequenceNumber)
        return .buffered
    }

    /// The last acknowledged sequence number (= nextExpected - 1).
    ///
    /// This is what goes in the ACK packet.
    public var lastAcknowledged: SequenceNumber {
        nextExpected - 1
    }

    /// Number of packets currently buffered (out of order, waiting for gaps to fill).
    public var bufferedCount: Int {
        buffered.count
    }

    /// Whether there are gaps in the received sequence.
    public var hasGaps: Bool {
        !buffered.isEmpty
    }

    /// List of missing sequence numbers (gaps between nextExpected and highest received).
    ///
    /// Used for NAK generation.
    public var missingSequenceNumbers: [SequenceNumber] {
        guard let highest = highestReceived else { return [] }
        let dist = SequenceNumber.distance(from: nextExpected, to: highest)
        guard dist > 0 else { return [] }

        var missing: [SequenceNumber] = []
        var current = nextExpected
        for _ in 0..<dist {
            if buffered[current] == nil {
                missing.append(current)
            }
            current += 1
        }
        return missing
    }

    /// Drop packets up to and including the given sequence number.
    ///
    /// Used for too-late packet drop. Advances nextExpected past the dropped range.
    /// - Parameter sequenceNumber: The sequence number to drop up to.
    public mutating func drop(upTo sequenceNumber: SequenceNumber) {
        let target = sequenceNumber + 1
        let dist = SequenceNumber.distance(from: nextExpected, to: target)
        guard dist > 0 else { return }

        // Remove any buffered packets in the dropped range
        var current = nextExpected
        for _ in 0..<dist {
            buffered.removeValue(forKey: current)
            current += 1
        }
        nextExpected = target
    }

    /// Number of packets available for delivery (at the head, in order).
    public var deliverableCount: Int {
        var count = 0
        var seq = nextExpected
        while buffered[seq] != nil {
            count += 1
            seq += 1
        }
        return count
    }

    /// Remove all buffered packets.
    public mutating func removeAll() {
        buffered.removeAll()
        highestReceived = nil
    }

    // MARK: - Private

    /// Delivers the given packet and any consecutive buffered successors.
    private mutating func deliverChain(
        startingWith packet: ReceivedPacket
    ) -> InsertResult {
        var chain: [ReceivedPacket] = [packet]
        nextExpected = packet.sequenceNumber + 1
        updateHighestReceived(packet.sequenceNumber)

        while let next = buffered.removeValue(forKey: nextExpected) {
            chain.append(next)
            nextExpected += 1
        }

        return .deliverable(packets: chain)
    }

    /// Updates the highest received tracking.
    private mutating func updateHighestReceived(_ seq: SequenceNumber) {
        if let current = highestReceived {
            if seq > current {
                highestReceived = seq
            }
        } else {
            highestReceived = seq
        }
    }
}
