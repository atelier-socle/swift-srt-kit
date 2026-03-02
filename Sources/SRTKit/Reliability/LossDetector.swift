// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Detects packet loss and maintains the loss list for NAK reporting.
///
/// Tracks which sequence numbers are missing and determines when
/// to (re-)report losses based on the NAK period.
public struct LossDetector: Sendable {
    /// A detected loss entry.
    public struct LossEntry: Sendable, Equatable {
        /// The lost sequence number.
        public let sequenceNumber: SequenceNumber
        /// When this loss was first detected (µs timestamp).
        public let detectedAt: UInt64
        /// When this loss was last reported in a NAK (µs timestamp).
        public var lastReportedAt: UInt64?
        /// Number of times this loss has been reported.
        public var reportCount: Int

        /// Creates a new loss entry.
        ///
        /// - Parameters:
        ///   - sequenceNumber: The lost sequence number.
        ///   - detectedAt: When this loss was first detected (µs timestamp).
        public init(sequenceNumber: SequenceNumber, detectedAt: UInt64) {
            self.sequenceNumber = sequenceNumber
            self.detectedAt = detectedAt
            self.lastReportedAt = nil
            self.reportCount = 0
        }
    }

    /// Active loss entries indexed by sequence number.
    private var losses: [SequenceNumber: LossEntry] = [:]

    /// Creates a new loss detector.
    public init() {}

    /// Record a detected gap (missing sequence numbers).
    ///
    /// - Parameters:
    ///   - sequenceNumbers: The missing sequence numbers.
    ///   - timestamp: Current time in microseconds.
    public mutating func addLoss(sequenceNumbers: [SequenceNumber], at timestamp: UInt64) {
        for seq in sequenceNumbers where losses[seq] == nil {
            losses[seq] = LossEntry(sequenceNumber: seq, detectedAt: timestamp)
        }
    }

    /// Remove recovered losses (packet arrived or was dropped).
    ///
    /// - Parameter sequenceNumbers: The recovered sequence numbers.
    public mutating func removeLoss(sequenceNumbers: [SequenceNumber]) {
        for seq in sequenceNumbers {
            losses.removeValue(forKey: seq)
        }
    }

    /// Remove all losses up to a sequence number (ACK frontier advanced).
    ///
    /// - Parameter sequenceNumber: The ACK frontier sequence number.
    public mutating func removeLoss(upTo sequenceNumber: SequenceNumber) {
        let keysToRemove = losses.keys.filter { key in
            key == sequenceNumber || SequenceNumber.distance(from: key, to: sequenceNumber) > 0
        }
        for key in keysToRemove {
            losses.removeValue(forKey: key)
        }
    }

    /// Get losses that need to be reported in a NAK.
    ///
    /// Returns losses that haven't been reported yet, or that need
    /// periodic re-reporting (NAK period expired).
    /// - Parameters:
    ///   - currentTime: Current time in microseconds.
    ///   - nakPeriod: NAK period in microseconds.
    /// - Returns: Sequence numbers to include in NAK.
    public func lossesNeedingReport(
        currentTime: UInt64,
        nakPeriod: UInt64
    ) -> [SequenceNumber] {
        var result: [SequenceNumber] = []
        for (_, entry) in losses {
            if entry.reportCount == 0 {
                // Never reported — needs immediate report
                result.append(entry.sequenceNumber)
            } else if let lastReport = entry.lastReportedAt,
                currentTime >= lastReport + nakPeriod
            {
                // NAK period expired — needs re-report
                result.append(entry.sequenceNumber)
            }
        }
        return result.sorted()
    }

    /// Mark losses as reported.
    ///
    /// - Parameters:
    ///   - sequenceNumbers: The reported sequence numbers.
    ///   - timestamp: Timestamp when the report was sent.
    public mutating func markReported(
        sequenceNumbers: [SequenceNumber],
        at timestamp: UInt64
    ) {
        for seq in sequenceNumbers {
            if var entry = losses[seq] {
                entry.lastReportedAt = timestamp
                entry.reportCount += 1
                losses[seq] = entry
            }
        }
    }

    /// Number of currently unrecovered losses.
    public var lossCount: Int {
        losses.count
    }

    /// Whether there are any unrecovered losses.
    public var hasLosses: Bool {
        !losses.isEmpty
    }

    /// All currently lost sequence numbers.
    public var allLosses: [SequenceNumber] {
        losses.keys.sorted()
    }
}
