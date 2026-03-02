// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore

/// A Drop Request packet CIF requesting the peer to drop specific packets.
///
/// The message number is carried in the control packet's `typeSpecificInfo` field.
/// The CIF contains two 32-bit words: the first and last sequence numbers to drop.
public struct DropRequestPacket: Sendable, Equatable {
    /// The CIF size in bytes.
    public static let cifSize = 8

    /// The message number (from `typeSpecificInfo`).
    public let messageNumber: UInt32
    /// The first sequence number to drop.
    public let firstSequence: SequenceNumber
    /// The last sequence number to drop.
    public let lastSequence: SequenceNumber

    /// Creates a new drop request packet.
    ///
    /// - Parameters:
    ///   - messageNumber: The message number.
    ///   - firstSequence: The first sequence number to drop.
    ///   - lastSequence: The last sequence number to drop.
    public init(
        messageNumber: UInt32,
        firstSequence: SequenceNumber,
        lastSequence: SequenceNumber
    ) {
        self.messageNumber = messageNumber
        self.firstSequence = firstSequence
        self.lastSequence = lastSequence
    }

    /// Encodes this drop request CIF into a buffer (8 bytes).
    ///
    /// - Parameter buffer: The buffer to write into.
    public func encode(into buffer: inout ByteBuffer) {
        buffer.writeInteger(firstSequence.value)
        buffer.writeInteger(lastSequence.value)
    }

    /// Decodes a drop request CIF from a buffer.
    ///
    /// - Parameters:
    ///   - buffer: The buffer to read from.
    ///   - messageNumber: The message number from `typeSpecificInfo`.
    /// - Returns: The decoded drop request packet.
    /// - Throws: `SRTError.invalidPacket` if the buffer is too small.
    public static func decode(from buffer: inout ByteBuffer, messageNumber: UInt32) throws -> DropRequestPacket {
        guard buffer.readableBytes >= cifSize else {
            throw SRTError.invalidPacket("Drop request CIF requires \(cifSize) bytes, got \(buffer.readableBytes)")
        }
        guard let first = buffer.readInteger(as: UInt32.self),
            let last = buffer.readInteger(as: UInt32.self)
        else {
            throw SRTError.invalidPacket("Failed to read drop request fields")
        }
        return DropRequestPacket(
            messageNumber: messageNumber,
            firstSequence: SequenceNumber(first),
            lastSequence: SequenceNumber(last)
        )
    }
}
