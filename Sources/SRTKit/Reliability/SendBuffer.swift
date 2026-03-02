// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Circular buffer of sent packets awaiting acknowledgement.
///
/// Packets are stored by sequence number and removed when ACKed.
/// The buffer enforces flow window limits — when full, no more
/// packets can be added until ACKs free space.
///
/// Thread safety: This is a value type designed to be used within
/// an actor. It does NOT need internal synchronization.
public struct SendBuffer: Sendable {
    /// A stored packet in the send buffer.
    public struct Entry: Sendable {
        /// The packet's sequence number.
        public let sequenceNumber: SequenceNumber
        /// The raw packet payload.
        public let payload: [UInt8]
        /// Timestamp when the packet was first sent (µs).
        public let sentTimestamp: UInt64
        /// Number of times this packet has been sent (1 = original, 2+ = retransmitted).
        public var sendCount: Int
        /// Message number (for message-based protocols).
        public let messageNumber: UInt32

        /// Creates a new send buffer entry.
        ///
        /// - Parameters:
        ///   - sequenceNumber: The packet's sequence number.
        ///   - payload: The raw packet payload.
        ///   - sentTimestamp: Timestamp when the packet was first sent (µs).
        ///   - sendCount: Number of times this packet has been sent.
        ///   - messageNumber: Message number for message-based protocols.
        public init(
            sequenceNumber: SequenceNumber,
            payload: [UInt8],
            sentTimestamp: UInt64,
            sendCount: Int = 1,
            messageNumber: UInt32 = 0
        ) {
            self.sequenceNumber = sequenceNumber
            self.payload = payload
            self.sentTimestamp = sentTimestamp
            self.sendCount = sendCount
            self.messageNumber = messageNumber
        }
    }

    /// Maximum number of packets the buffer can hold (flow window).
    public let capacity: Int

    /// Storage indexed by sequence number.
    private var entries: [SequenceNumber: Entry] = [:]

    /// The oldest unacknowledged sequence number.
    private var oldestUnacked: SequenceNumber?

    /// The newest inserted sequence number.
    private var newestInserted: SequenceNumber?

    /// Create a send buffer with the specified capacity.
    ///
    /// - Parameter capacity: Maximum number of packets the buffer can hold.
    public init(capacity: Int) {
        self.capacity = Swift.max(capacity, 1)
    }

    /// Insert a packet into the buffer.
    ///
    /// - Parameter entry: The packet entry to insert.
    /// - Returns: `true` if inserted, `false` if buffer is full.
    @discardableResult
    public mutating func insert(_ entry: Entry) -> Bool {
        guard entries.count < capacity else { return false }
        entries[entry.sequenceNumber] = entry
        if oldestUnacked == nil {
            oldestUnacked = entry.sequenceNumber
        }
        if let newest = newestInserted {
            if entry.sequenceNumber > newest {
                newestInserted = entry.sequenceNumber
            }
        } else {
            newestInserted = entry.sequenceNumber
        }
        return true
    }

    /// Acknowledge all packets up to and including the given sequence number.
    ///
    /// Removes them from the buffer.
    /// - Parameter sequenceNumber: The sequence number to acknowledge up to.
    /// - Returns: Number of packets removed.
    @discardableResult
    public mutating func acknowledge(upTo sequenceNumber: SequenceNumber) -> Int {
        var removed = 0
        let keysToRemove = entries.keys.filter { $0 <= sequenceNumber || $0 == sequenceNumber }
        for key in keysToRemove {
            // Use signed distance: if key <= sequenceNumber (accounting for wrap)
            if key == sequenceNumber || SequenceNumber.distance(from: key, to: sequenceNumber) >= 0 {
                entries.removeValue(forKey: key)
                removed += 1
            }
        }
        updateTracking()
        return removed
    }

    /// Retrieve a packet by sequence number (for retransmission).
    ///
    /// Increments the sendCount. Returns nil if not in buffer.
    /// - Parameter sequenceNumber: The sequence number to retrieve.
    /// - Returns: The entry if found, nil otherwise.
    public mutating func retrieve(sequenceNumber: SequenceNumber) -> Entry? {
        guard var entry = entries[sequenceNumber] else { return nil }
        entry.sendCount += 1
        entries[sequenceNumber] = entry
        return entry
    }

    /// Retrieve multiple packets by sequence numbers (batch retransmission).
    ///
    /// Increments sendCount for each. Returns only found entries.
    /// - Parameter sequenceNumbers: The sequence numbers to retrieve.
    /// - Returns: Found entries with incremented send counts.
    public mutating func retrieve(sequenceNumbers: [SequenceNumber]) -> [Entry] {
        var result: [Entry] = []
        for seq in sequenceNumbers {
            if let entry = retrieve(sequenceNumber: seq) {
                result.append(entry)
            }
        }
        return result
    }

    /// Number of packets currently in the buffer.
    public var count: Int {
        entries.count
    }

    /// Whether the buffer has reached its capacity.
    public var isFull: Bool {
        entries.count >= capacity
    }

    /// Whether the buffer is empty.
    public var isEmpty: Bool {
        entries.isEmpty
    }

    /// Available space in the buffer.
    public var availableSpace: Int {
        capacity - entries.count
    }

    /// The oldest unacknowledged sequence number, or nil if empty.
    public var oldestSequenceNumber: SequenceNumber? {
        oldestUnacked
    }

    /// The newest sequence number in the buffer, or nil if empty.
    public var newestSequenceNumber: SequenceNumber? {
        newestInserted
    }

    /// Remove all entries from the buffer.
    public mutating func removeAll() {
        entries.removeAll()
        oldestUnacked = nil
        newestInserted = nil
    }

    /// Remove packets older than a given timestamp (too-late drop on sender side).
    ///
    /// - Parameter timestamp: The timestamp threshold in microseconds.
    /// - Returns: The sequence numbers of dropped packets.
    public mutating func dropOlderThan(timestamp: UInt64) -> [SequenceNumber] {
        var dropped: [SequenceNumber] = []
        for (key, entry) in entries where entry.sentTimestamp < timestamp {
            dropped.append(key)
        }
        for key in dropped {
            entries.removeValue(forKey: key)
        }
        if !dropped.isEmpty {
            updateTracking()
        }
        return dropped
    }

    // MARK: - Private

    /// Recalculates oldest and newest tracking after removals.
    private mutating func updateTracking() {
        if entries.isEmpty {
            oldestUnacked = nil
            newestInserted = nil
        } else {
            oldestUnacked = entries.keys.min()
            newestInserted = entries.keys.max()
        }
    }
}
