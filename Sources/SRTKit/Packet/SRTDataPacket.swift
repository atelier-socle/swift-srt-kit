// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// An SRT data packet carrying payload bytes.
///
/// Data packets have `F=0` (bit 0 of word 0). The header format is:
/// - **Word 0:** `0` (1 bit) | sequence number (31 bits)
/// - **Word 1:** PP (2 bits) | O (1 bit) | KK (2 bits) | R (1 bit) | message number (26 bits)
/// - **Word 2:** timestamp (32 bits)
/// - **Word 3:** destination socket ID (32 bits)
/// - **Remaining:** payload
public struct SRTDataPacket: Sendable, Hashable {
    /// The position of this packet within a message.
    public enum Position: UInt8, Sendable, Hashable, CaseIterable, CustomStringConvertible {
        /// First packet of a multi-packet message.
        case first = 0b10
        /// Middle packet of a multi-packet message.
        case middle = 0b00
        /// Last packet of a multi-packet message.
        case last = 0b01
        /// Single packet containing the entire message.
        case single = 0b11

        /// A human-readable description of the position.
        public var description: String {
            switch self {
            case .first: "first"
            case .middle: "middle"
            case .last: "last"
            case .single: "single"
            }
        }
    }

    /// The encryption key indicator for this packet.
    public enum EncryptionKey: UInt8, Sendable, Hashable, CaseIterable, CustomStringConvertible {
        /// No encryption.
        case none = 0b00
        /// Encrypted with the even key.
        case even = 0b01
        /// Encrypted with the odd key.
        case odd = 0b10
        /// Control-only encryption marker.
        case controlOnly = 0b11

        /// A human-readable description of the encryption key.
        public var description: String {
            switch self {
            case .none: "none"
            case .even: "even"
            case .odd: "odd"
            case .controlOnly: "controlOnly"
            }
        }
    }

    /// The 31-bit packet sequence number.
    public let sequenceNumber: SequenceNumber

    /// The position of this packet within a message.
    public let position: Position

    /// Whether in-order delivery is requested.
    public let orderFlag: Bool

    /// The encryption key indicator.
    public let encryptionKey: EncryptionKey

    /// Whether this packet is a retransmission.
    public let retransmitted: Bool

    /// The 26-bit message number.
    public let messageNumber: UInt32

    /// The packet timestamp in microseconds.
    public let timestamp: UInt32

    /// The destination socket identifier.
    public let destinationSocketID: UInt32

    /// The payload bytes.
    public let payload: [UInt8]

    /// The maximum value for a 26-bit message number.
    public static let maxMessageNumber: UInt32 = 0x03FF_FFFF

    /// Creates a new SRT data packet.
    ///
    /// - Parameters:
    ///   - sequenceNumber: The 31-bit packet sequence number.
    ///   - position: The position within a message.
    ///   - orderFlag: Whether in-order delivery is requested.
    ///   - encryptionKey: The encryption key indicator.
    ///   - retransmitted: Whether this is a retransmission.
    ///   - messageNumber: The 26-bit message number (masked to 26 bits).
    ///   - timestamp: The packet timestamp in microseconds.
    ///   - destinationSocketID: The destination socket identifier.
    ///   - payload: The payload bytes.
    public init(
        sequenceNumber: SequenceNumber,
        position: Position = .single,
        orderFlag: Bool = false,
        encryptionKey: EncryptionKey = .none,
        retransmitted: Bool = false,
        messageNumber: UInt32 = 0,
        timestamp: UInt32 = 0,
        destinationSocketID: UInt32 = 0,
        payload: [UInt8] = []
    ) {
        self.sequenceNumber = sequenceNumber
        self.position = position
        self.orderFlag = orderFlag
        self.encryptionKey = encryptionKey
        self.retransmitted = retransmitted
        self.messageNumber = messageNumber & Self.maxMessageNumber
        self.timestamp = timestamp
        self.destinationSocketID = destinationSocketID
        self.payload = payload
    }
}
