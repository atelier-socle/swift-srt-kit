// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore

/// An ACK (Acknowledgement) packet CIF.
///
/// ACK packets come in two forms:
/// - **Light ACK**: 4 bytes, only the acknowledged sequence number
/// - **Full ACK**: 28 bytes, includes RTT, variance, buffer, rate, and capacity stats
public struct ACKPacket: Sendable, Equatable {
    /// The CIF size for a light ACK in bytes.
    public static let lightACKSize = 4
    /// The CIF size for a full ACK in bytes.
    public static let fullACKSize = 28

    /// The acknowledged data packet sequence number (last received + 1).
    public let acknowledgementNumber: SequenceNumber

    /// Round-trip time in microseconds (full ACK only).
    public let rtt: UInt32?
    /// RTT variance in microseconds (full ACK only).
    public let rttVariance: UInt32?
    /// Available buffer size in packets (full ACK only).
    public let availableBufferSize: UInt32?
    /// Packets receiving rate in packets/second (full ACK only).
    public let packetsReceivingRate: UInt32?
    /// Estimated link capacity in packets/second (full ACK only).
    public let estimatedLinkCapacity: UInt32?
    /// Receiving rate in bytes/second (full ACK only).
    public let receivingRate: UInt32?

    /// Whether this is a light ACK (no extended fields).
    public var isLightACK: Bool { rtt == nil }

    /// Creates a new ACK packet.
    ///
    /// - Parameters:
    ///   - acknowledgementNumber: The acknowledged sequence number.
    ///   - rtt: Round-trip time in microseconds (nil for light ACK).
    ///   - rttVariance: RTT variance in microseconds.
    ///   - availableBufferSize: Available buffer size in packets.
    ///   - packetsReceivingRate: Packets receiving rate.
    ///   - estimatedLinkCapacity: Estimated link capacity.
    ///   - receivingRate: Receiving rate in bytes/second.
    public init(
        acknowledgementNumber: SequenceNumber,
        rtt: UInt32? = nil,
        rttVariance: UInt32? = nil,
        availableBufferSize: UInt32? = nil,
        packetsReceivingRate: UInt32? = nil,
        estimatedLinkCapacity: UInt32? = nil,
        receivingRate: UInt32? = nil
    ) {
        self.acknowledgementNumber = acknowledgementNumber
        self.rtt = rtt
        self.rttVariance = rttVariance
        self.availableBufferSize = availableBufferSize
        self.packetsReceivingRate = packetsReceivingRate
        self.estimatedLinkCapacity = estimatedLinkCapacity
        self.receivingRate = receivingRate
    }

    /// Encodes this ACK CIF into a buffer.
    ///
    /// Writes 4 bytes for light ACK or 28 bytes for full ACK.
    /// - Parameter buffer: The buffer to write into.
    public func encode(into buffer: inout ByteBuffer) {
        buffer.writeInteger(acknowledgementNumber.value)
        if let rtt {
            buffer.writeInteger(rtt)
            buffer.writeInteger(rttVariance ?? 0)
            buffer.writeInteger(availableBufferSize ?? 0)
            buffer.writeInteger(packetsReceivingRate ?? 0)
            buffer.writeInteger(estimatedLinkCapacity ?? 0)
            buffer.writeInteger(receivingRate ?? 0)
        }
    }

    /// Decodes an ACK CIF from a buffer.
    ///
    /// - Parameters:
    ///   - buffer: The buffer to read from.
    ///   - cifLength: The length of the CIF in bytes (4 for light, 28 for full).
    /// - Returns: The decoded ACK packet.
    /// - Throws: `SRTError.invalidPacket` if the CIF length is invalid.
    public static func decode(from buffer: inout ByteBuffer, cifLength: Int) throws -> ACKPacket {
        guard cifLength >= lightACKSize else {
            throw SRTError.invalidPacket("ACK CIF too small: \(cifLength) bytes")
        }
        guard let ackSeq = buffer.readInteger(as: UInt32.self) else {
            throw SRTError.invalidPacket("Failed to read ACK sequence number")
        }

        if cifLength < fullACKSize {
            return ACKPacket(acknowledgementNumber: SequenceNumber(ackSeq))
        }

        guard let rtt = buffer.readInteger(as: UInt32.self),
            let rttVar = buffer.readInteger(as: UInt32.self),
            let bufSize = buffer.readInteger(as: UInt32.self),
            let pktRate = buffer.readInteger(as: UInt32.self),
            let linkCap = buffer.readInteger(as: UInt32.self),
            let recvRate = buffer.readInteger(as: UInt32.self)
        else {
            throw SRTError.invalidPacket("Failed to read full ACK fields")
        }

        return ACKPacket(
            acknowledgementNumber: SequenceNumber(ackSeq),
            rtt: rtt,
            rttVariance: rttVar,
            availableBufferSize: bufSize,
            packetsReceivingRate: pktRate,
            estimatedLinkCapacity: linkCap,
            receivingRate: recvRate
        )
    }
}
