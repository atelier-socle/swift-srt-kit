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

/// A typed Control Information Field (CIF) for SRT control packets.
///
/// Each control packet type has a specific CIF format. This enum provides
/// type-safe access to the parsed CIF data.
public enum ControlInfoField: Sendable, Equatable {
    /// Handshake CIF (48 bytes).
    case handshake(HandshakePacket)
    /// ACK CIF (4 or 28 bytes).
    case ack(ACKPacket)
    /// NAK CIF (variable length loss list).
    case nak(NAKPacket)
    /// Drop request CIF (8 bytes).
    case dropRequest(DropRequestPacket)
    /// Key material CIF (variable length).
    case keyMaterial(KeyMaterialPacket)
    /// Keep-alive (no CIF).
    case keepalive
    /// Shutdown (no CIF).
    case shutdown
    /// ACK-ACK (no CIF).
    case ackack
    /// Peer error with error code.
    case peerError(UInt32)
    /// Raw bytes for unknown or untyped CIF.
    case raw([UInt8])
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

    // MARK: - Typed CIF Encoding/Decoding

    /// Decodes a control packet's CIF based on its type.
    ///
    /// - Parameters:
    ///   - controlType: The type of the control packet.
    ///   - buffer: The buffer containing the CIF bytes.
    ///   - cifLength: The length of the CIF in bytes.
    ///   - typeSpecificInfo: The type-specific info from the control header.
    /// - Returns: The decoded typed CIF.
    /// - Throws: `SRTError.invalidPacket` if the CIF is invalid.
    public static func decodeCIF(
        controlType: ControlType,
        from buffer: inout ByteBuffer,
        cifLength: Int,
        typeSpecificInfo: UInt32 = 0
    ) throws -> ControlInfoField {
        switch controlType {
        case .handshake:
            return .handshake(try HandshakePacket.decode(from: &buffer))
        case .ack:
            return .ack(try ACKPacket.decode(from: &buffer, cifLength: cifLength))
        case .nak:
            return .nak(try NAKPacket.decode(from: &buffer, cifLength: cifLength))
        case .dropreq:
            return .dropRequest(try DropRequestPacket.decode(from: &buffer, messageNumber: typeSpecificInfo))
        case .keepalive:
            return .keepalive
        case .shutdown:
            return .shutdown
        case .ackack:
            return .ackack
        case .peererror:
            return decodePeerErrorCIF(from: &buffer, cifLength: cifLength)
        case .congestion, .userDefined:
            return try decodeRawCIF(from: &buffer, cifLength: cifLength)
        }
    }

    /// Decodes a peer error CIF from the buffer.
    private static func decodePeerErrorCIF(from buffer: inout ByteBuffer, cifLength: Int) -> ControlInfoField {
        if cifLength >= 4, let code = buffer.readInteger(as: UInt32.self) {
            return .peerError(code)
        }
        return .peerError(0)
    }

    /// Decodes a raw CIF from the buffer.
    private static func decodeRawCIF(from buffer: inout ByteBuffer, cifLength: Int) throws -> ControlInfoField {
        guard cifLength > 0 else { return .raw([]) }
        guard let bytes = buffer.readBytes(length: cifLength) else {
            throw SRTError.invalidPacket("Failed to read raw CIF")
        }
        return .raw(bytes)
    }

    /// Encodes a control packet with a typed CIF into a buffer.
    ///
    /// - Parameters:
    ///   - controlType: The control packet type.
    ///   - subtype: The control packet subtype.
    ///   - typeSpecificInfo: The type-specific info field.
    ///   - timestamp: The packet timestamp.
    ///   - destinationSocketID: The destination socket ID.
    ///   - cif: The typed CIF to encode.
    ///   - buffer: The buffer to write into.
    public static func encode(
        controlType: ControlType,
        subtype: UInt16 = 0,
        typeSpecificInfo: UInt32 = 0,
        timestamp: UInt32 = 0,
        destinationSocketID: UInt32 = 0,
        cif: ControlInfoField,
        into buffer: inout ByteBuffer
    ) {
        // Write control header
        var word0 = UInt32(0x8000_0000)
        word0 |= UInt32(controlType.rawValue) << 16
        word0 |= UInt32(subtype)
        buffer.writeInteger(word0)
        buffer.writeInteger(typeSpecificInfo)
        buffer.writeInteger(timestamp)
        buffer.writeInteger(destinationSocketID)

        // Write CIF
        switch cif {
        case .handshake(let hs):
            hs.encode(into: &buffer)
        case .ack(let ack):
            ack.encode(into: &buffer)
        case .nak(let nak):
            nak.encode(into: &buffer)
        case .dropRequest(let drop):
            drop.encode(into: &buffer)
        case .keyMaterial(let km):
            km.encode(into: &buffer)
        case .peerError(let code):
            buffer.writeInteger(code)
        case .raw(let bytes):
            if !bytes.isEmpty {
                buffer.writeBytes(bytes)
            }
        case .keepalive, .shutdown, .ackack:
            break
        }
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
