// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Manages NAK-triggered retransmission from the send buffer.
///
/// Processes incoming NAK packets, retrieves lost packets from the
/// send buffer, and tracks retransmission statistics.
public struct RetransmissionManager: Sendable {
    /// A retransmission request.
    public struct RetransmitRequest: Sendable {
        /// Sequence number to retransmit.
        public let sequenceNumber: SequenceNumber
        /// The packet payload.
        public let payload: [UInt8]
        /// Original timestamp.
        public let originalTimestamp: UInt64
        /// Send count (will be 2+ for retransmissions).
        public let sendCount: Int

        /// Creates a new retransmit request.
        ///
        /// - Parameters:
        ///   - sequenceNumber: Sequence number to retransmit.
        ///   - payload: The packet payload.
        ///   - originalTimestamp: Original timestamp when the packet was first sent.
        ///   - sendCount: Send count (will be 2+ for retransmissions).
        public init(
            sequenceNumber: SequenceNumber,
            payload: [UInt8],
            originalTimestamp: UInt64,
            sendCount: Int
        ) {
            self.sequenceNumber = sequenceNumber
            self.payload = payload
            self.originalTimestamp = originalTimestamp
            self.sendCount = sendCount
        }
    }

    /// Total number of retransmissions performed.
    public private(set) var totalRetransmissions: Int = 0

    /// Total number of packets requested but not found in send buffer.
    public private(set) var missingFromBuffer: Int = 0

    /// Creates a new retransmission manager.
    public init() {}

    /// Process a NAK loss list and determine which packets need retransmission.
    ///
    /// - Parameters:
    ///   - lostSequenceNumbers: Sequence numbers reported lost.
    ///   - sendBuffer: The send buffer to retrieve packets from.
    /// - Returns: Packets to retransmit (empty if packets no longer in buffer).
    public mutating func processNAK(
        lostSequenceNumbers: [SequenceNumber],
        sendBuffer: inout SendBuffer
    ) -> [RetransmitRequest] {
        var requests: [RetransmitRequest] = []

        for seq in lostSequenceNumbers {
            if let entry = sendBuffer.retrieve(sequenceNumber: seq) {
                requests.append(
                    RetransmitRequest(
                        sequenceNumber: entry.sequenceNumber,
                        payload: entry.payload,
                        originalTimestamp: entry.sentTimestamp,
                        sendCount: entry.sendCount
                    ))
                totalRetransmissions += 1
            } else {
                missingFromBuffer += 1
            }
        }

        return requests
    }

    /// Reset statistics.
    public mutating func resetStatistics() {
        totalRetransmissions = 0
        missingFromBuffer = 0
    }
}
