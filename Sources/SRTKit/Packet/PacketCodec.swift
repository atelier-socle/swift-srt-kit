// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore

/// A decoded SRT packet, either data or control.
public enum SRTPacket: Sendable, Hashable {
    /// A data packet carrying payload.
    case data(SRTDataPacket)
    /// A control packet for protocol signaling.
    case control(SRTControlPacket)
}

/// Codec for encoding and decoding SRT packets to/from `ByteBuffer`.
///
/// All fields are big-endian (network byte order). The F bit (bit 0 of word 0)
/// determines whether the packet is data (`F=0`) or control (`F=1`).
///
/// Minimum packet size is 16 bytes (header only, no payload/CIF).
public enum PacketCodec: Sendable {
    /// The minimum SRT packet header size in bytes.
    public static let minimumHeaderSize = 16

    /// Decodes an SRT packet from a `ByteBuffer`.
    ///
    /// - Parameter buffer: The buffer containing the packet bytes. The reader index is advanced.
    /// - Returns: The decoded packet.
    /// - Throws: `SRTError.invalidPacket` if the buffer is too small or contains invalid data.
    public static func decode(from buffer: inout ByteBuffer) throws -> SRTPacket {
        guard buffer.readableBytes >= minimumHeaderSize else {
            throw SRTError.invalidPacket("Buffer too small: \(buffer.readableBytes) bytes, minimum \(minimumHeaderSize)")
        }

        guard let word0 = buffer.readInteger(as: UInt32.self) else {
            throw SRTError.invalidPacket("Failed to read word 0")
        }

        let isControl = (word0 & 0x8000_0000) != 0

        if isControl {
            return try .control(decodeControl(word0: word0, buffer: &buffer))
        } else {
            return try .data(decodeData(word0: word0, buffer: &buffer))
        }
    }

    /// Encodes an SRT packet into a `ByteBuffer`.
    ///
    /// - Parameters:
    ///   - packet: The packet to encode.
    ///   - buffer: The buffer to write the encoded bytes into.
    public static func encode(_ packet: SRTPacket, into buffer: inout ByteBuffer) {
        switch packet {
        case .data(let dataPacket):
            encodeData(dataPacket, into: &buffer)
        case .control(let controlPacket):
            encodeControl(controlPacket, into: &buffer)
        }
    }

    // MARK: - Data Packet Encoding/Decoding

    private static func decodeData(word0: UInt32, buffer: inout ByteBuffer) throws -> SRTDataPacket {
        let sequenceNumber = SequenceNumber(word0 & 0x7FFF_FFFF)

        guard let word1 = buffer.readInteger(as: UInt32.self) else {
            throw SRTError.invalidPacket("Failed to read word 1")
        }

        let pp = UInt8((word1 >> 30) & 0x03)
        let orderFlag = (word1 & 0x2000_0000) != 0
        let kk = UInt8((word1 >> 27) & 0x03)
        let retransmitted = (word1 & 0x0400_0000) != 0
        let messageNumber = word1 & 0x03FF_FFFF

        guard let position = SRTDataPacket.Position(rawValue: pp) else {
            throw SRTError.invalidPacket("Invalid position: \(pp)")
        }
        guard let encryptionKey = SRTDataPacket.EncryptionKey(rawValue: kk) else {
            throw SRTError.invalidPacket("Invalid encryption key: \(kk)")
        }

        guard let timestamp = buffer.readInteger(as: UInt32.self) else {
            throw SRTError.invalidPacket("Failed to read timestamp")
        }
        guard let destinationSocketID = buffer.readInteger(as: UInt32.self) else {
            throw SRTError.invalidPacket("Failed to read destination socket ID")
        }

        let payload: [UInt8]
        if buffer.readableBytes > 0 {
            guard let bytes = buffer.readBytes(length: buffer.readableBytes) else {
                throw SRTError.invalidPacket("Failed to read payload")
            }
            payload = bytes
        } else {
            payload = []
        }

        return SRTDataPacket(
            sequenceNumber: sequenceNumber,
            position: position,
            orderFlag: orderFlag,
            encryptionKey: encryptionKey,
            retransmitted: retransmitted,
            messageNumber: messageNumber,
            timestamp: timestamp,
            destinationSocketID: destinationSocketID,
            payload: payload
        )
    }

    private static func encodeData(_ packet: SRTDataPacket, into buffer: inout ByteBuffer) {
        // Word 0: F=0 | sequence number (31 bits)
        let word0 = packet.sequenceNumber.value & 0x7FFF_FFFF
        buffer.writeInteger(word0)

        // Word 1: PP(2) | O(1) | KK(2) | R(1) | message number(26)
        var word1 = UInt32(packet.position.rawValue) << 30
        if packet.orderFlag {
            word1 |= 0x2000_0000
        }
        word1 |= UInt32(packet.encryptionKey.rawValue) << 27
        if packet.retransmitted {
            word1 |= 0x0400_0000
        }
        word1 |= packet.messageNumber & 0x03FF_FFFF
        buffer.writeInteger(word1)

        // Word 2: timestamp
        buffer.writeInteger(packet.timestamp)

        // Word 3: destination socket ID
        buffer.writeInteger(packet.destinationSocketID)

        // Payload
        if !packet.payload.isEmpty {
            buffer.writeBytes(packet.payload)
        }
    }

    // MARK: - Control Packet Encoding/Decoding

    private static func decodeControl(word0: UInt32, buffer: inout ByteBuffer) throws -> SRTControlPacket {
        let controlTypeRaw = UInt16((word0 >> 16) & 0x7FFF)
        let subtype = UInt16(word0 & 0xFFFF)

        guard let controlType = ControlType(rawValue: controlTypeRaw) else {
            throw SRTError.invalidPacket("Unknown control type: 0x\(String(controlTypeRaw, radix: 16))")
        }

        guard let typeSpecificInfo = buffer.readInteger(as: UInt32.self) else {
            throw SRTError.invalidPacket("Failed to read type-specific info")
        }
        guard let timestamp = buffer.readInteger(as: UInt32.self) else {
            throw SRTError.invalidPacket("Failed to read timestamp")
        }
        guard let destinationSocketID = buffer.readInteger(as: UInt32.self) else {
            throw SRTError.invalidPacket("Failed to read destination socket ID")
        }

        let controlInfoField: [UInt8]
        if buffer.readableBytes > 0 {
            guard let bytes = buffer.readBytes(length: buffer.readableBytes) else {
                throw SRTError.invalidPacket("Failed to read control info field")
            }
            controlInfoField = bytes
        } else {
            controlInfoField = []
        }

        return SRTControlPacket(
            controlType: controlType,
            subtype: subtype,
            typeSpecificInfo: typeSpecificInfo,
            timestamp: timestamp,
            destinationSocketID: destinationSocketID,
            controlInfoField: controlInfoField
        )
    }

    private static func encodeControl(_ packet: SRTControlPacket, into buffer: inout ByteBuffer) {
        // Word 0: F=1 | control type (15 bits) | subtype (16 bits)
        var word0 = UInt32(0x8000_0000)
        word0 |= UInt32(packet.controlType.rawValue) << 16
        word0 |= UInt32(packet.subtype)
        buffer.writeInteger(word0)

        // Word 1: type-specific info
        buffer.writeInteger(packet.typeSpecificInfo)

        // Word 2: timestamp
        buffer.writeInteger(packet.timestamp)

        // Word 3: destination socket ID
        buffer.writeInteger(packet.destinationSocketID)

        // CIF
        if !packet.controlInfoField.isEmpty {
            buffer.writeBytes(packet.controlInfoField)
        }
    }
}
