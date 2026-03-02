// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Deduplicates packets received on multiple links.
///
/// Uses a sliding window of recently received sequence numbers
/// to efficiently detect duplicates without unbounded memory.
public struct PacketDeduplicator: Sendable {
    /// Window size in sequence numbers (default: 4096).
    public let windowSize: Int

    /// Bit array for tracking seen sequence numbers.
    private var seen: [Bool]

    /// Number of duplicates detected.
    private var duplicatesCount: Int = 0

    /// Creates a packet deduplicator.
    ///
    /// - Parameter windowSize: Window size in sequence numbers.
    public init(windowSize: Int = 4096) {
        self.windowSize = windowSize
        self.seen = [Bool](repeating: false, count: windowSize)
    }

    /// Check if a sequence number has already been received.
    ///
    /// - Parameter sequenceNumber: The sequence number to check.
    /// - Returns: true if this is a new (not yet seen) sequence number.
    public mutating func isNew(_ sequenceNumber: SequenceNumber) -> Bool {
        let index = Int(sequenceNumber.value) % windowSize
        if seen[index] {
            duplicatesCount += 1
            return false
        }
        seen[index] = true
        return true
    }

    /// Number of duplicates detected.
    public var duplicatesDetected: Int { duplicatesCount }

    /// Reset state.
    public mutating func reset() {
        seen = [Bool](repeating: false, count: windowSize)
        duplicatesCount = 0
    }
}
