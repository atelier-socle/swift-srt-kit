// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Manages ACK generation and ACKACK processing.
///
/// Determines when to send periodic full ACKs (every 10ms or 64 packets)
/// and light ACKs between periodic intervals. Also tracks outstanding
/// ACKs for RTT measurement via ACKACK.
public struct ACKManager: Sendable {
    /// SYN interval in microseconds (10ms).
    public static let synInterval: UInt64 = 10_000

    /// Packets between periodic ACKs.
    public static let packetsPerACK: Int = 64

    /// Maximum age for pending ACKs before cleanup (10 seconds).
    private static let maxPendingAge: UInt64 = 10_000_000

    /// An ACK action to take.
    public enum ACKAction: Sendable, Equatable {
        /// Send a full ACK with all statistics.
        case sendFullACK(ackSequenceNumber: UInt32, lastACKedSequence: SequenceNumber)
        /// Send a light ACK with only the last acknowledged sequence.
        case sendLightACK(lastACKedSequence: SequenceNumber)
        /// No ACK needed right now.
        case none
    }

    /// A pending ACK awaiting ACKACK response.
    public struct PendingACK: Sendable {
        /// The ACK sequence number.
        public let ackSequenceNumber: UInt32
        /// Timestamp when ACK was sent (µs).
        public let sentAt: UInt64
        /// The sequence number that was acknowledged.
        public let acknowledgedSequence: SequenceNumber
    }

    /// Monotonically increasing ACK sequence number counter.
    private var nextACKSequenceNumber: UInt32 = 1

    /// Pending ACKs awaiting ACKACK.
    private var pendingACKs: [UInt32: PendingACK] = [:]

    /// Packets received since last full ACK.
    private var packetsSinceLastACK: Int = 0

    /// Timestamp of the last periodic full ACK.
    private var lastPeriodicACKTime: UInt64 = 0

    /// The last acknowledged sequence sent in an ACK.
    private var lastACKedSequence: SequenceNumber?

    /// Whether any new data has arrived since the last ACK.
    private var hasNewData: Bool = false

    /// Creates a new ACK manager.
    public init() {}

    /// Notify the manager that a data packet was received.
    ///
    /// - Parameters:
    ///   - currentTime: Current time in microseconds.
    ///   - lastAcknowledged: Current last acknowledged sequence number.
    /// - Returns: Whether an ACK should be sent.
    public mutating func packetReceived(
        currentTime: UInt64,
        lastAcknowledged: SequenceNumber
    ) -> ACKAction {
        packetsSinceLastACK += 1
        hasNewData = true

        // Check packet count threshold
        if packetsSinceLastACK >= Self.packetsPerACK {
            return generateFullACK(currentTime: currentTime, lastAcknowledged: lastAcknowledged)
        }

        // Check time threshold
        if currentTime >= lastPeriodicACKTime + Self.synInterval {
            return generateFullACK(currentTime: currentTime, lastAcknowledged: lastAcknowledged)
        }

        // Light ACK if new data and sequence advanced
        if let prevACKed = lastACKedSequence, lastAcknowledged != prevACKed {
            return .sendLightACK(lastACKedSequence: lastAcknowledged)
        }

        return .none
    }

    /// Check if a periodic ACK is due based on time.
    ///
    /// - Parameters:
    ///   - currentTime: Current time in microseconds.
    ///   - lastAcknowledged: Current last acknowledged sequence number.
    /// - Returns: ACK action.
    public mutating func checkPeriodicACK(
        currentTime: UInt64,
        lastAcknowledged: SequenceNumber
    ) -> ACKAction {
        guard currentTime >= lastPeriodicACKTime + Self.synInterval else {
            return .none
        }
        guard hasNewData else {
            return .none
        }
        return generateFullACK(currentTime: currentTime, lastAcknowledged: lastAcknowledged)
    }

    /// Record that a full ACK was sent (track for ACKACK matching).
    ///
    /// - Parameters:
    ///   - ackSequenceNumber: The ACK sequence number.
    ///   - sentAt: Timestamp when ACK was sent.
    ///   - acknowledgedSequence: The sequence number acknowledged.
    public mutating func ackSent(
        ackSequenceNumber: UInt32,
        sentAt: UInt64,
        acknowledgedSequence: SequenceNumber
    ) {
        pendingACKs[ackSequenceNumber] = PendingACK(
            ackSequenceNumber: ackSequenceNumber,
            sentAt: sentAt,
            acknowledgedSequence: acknowledgedSequence
        )
        cleanupOldPendingACKs(currentTime: sentAt)
    }

    /// Process a received ACKACK. Returns the RTT measurement if the ACK was found.
    ///
    /// - Parameters:
    ///   - ackSequenceNumber: The ACK sequence number from the ACKACK.
    ///   - receivedAt: Timestamp when ACKACK was received.
    /// - Returns: RTT in microseconds, or nil if ACK sequence number not found.
    public mutating func processACKACK(
        ackSequenceNumber: UInt32,
        receivedAt: UInt64
    ) -> UInt64? {
        guard let pending = pendingACKs.removeValue(forKey: ackSequenceNumber) else {
            return nil
        }
        return receivedAt - pending.sentAt
    }

    /// Current ACK sequence number counter.
    public var currentACKSequenceNumber: UInt32 {
        nextACKSequenceNumber
    }

    /// Number of ACKs pending ACKACK response.
    public var pendingACKCount: Int {
        pendingACKs.count
    }

    // MARK: - Private

    /// Generates a full ACK and resets counters.
    private mutating func generateFullACK(
        currentTime: UInt64,
        lastAcknowledged: SequenceNumber
    ) -> ACKAction {
        let ackSeq = nextACKSequenceNumber
        nextACKSequenceNumber += 1
        packetsSinceLastACK = 0
        lastPeriodicACKTime = currentTime
        lastACKedSequence = lastAcknowledged
        hasNewData = false
        return .sendFullACK(ackSequenceNumber: ackSeq, lastACKedSequence: lastAcknowledged)
    }

    /// Remove pending ACKs older than the maximum age.
    private mutating func cleanupOldPendingACKs(currentTime: UInt64) {
        guard currentTime > Self.maxPendingAge else { return }
        let threshold = currentTime - Self.maxPendingAge
        let keysToRemove = pendingACKs.keys.filter { key in
            guard let pending = pendingACKs[key] else { return false }
            return pending.sentAt < threshold
        }
        for key in keysToRemove {
            pendingACKs.removeValue(forKey: key)
        }
    }
}
