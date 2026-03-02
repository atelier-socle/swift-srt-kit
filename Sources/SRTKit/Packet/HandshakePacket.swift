// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore

/// A 48-byte Handshake Control Information Field (CIF).
///
/// The handshake CIF is carried inside an `SRTControlPacket` with
/// `controlType == .handshake`. It contains connection negotiation parameters
/// including version, encryption, MTU, flow window, peer address, and more.
public struct HandshakePacket: Sendable, Equatable {
    /// The type of handshake message.
    public enum HandshakeType: UInt32, Sendable, Hashable, CaseIterable, CustomStringConvertible {
        /// Handshake completed successfully.
        case done = 0xFFFF_FFFD
        /// Agreement phase (rendezvous mode).
        case agreement = 0xFFFF_FFFE
        /// Conclusion phase (final handshake).
        case conclusion = 0xFFFF_FFFF
        /// Initial waveahand (first packet from caller).
        case waveahand = 0x0000_0000
        /// Induction phase (listener response to waveahand).
        case induction = 0x0000_0001

        /// A human-readable description of the handshake type.
        public var description: String {
            switch self {
            case .done: "done"
            case .agreement: "agreement"
            case .conclusion: "conclusion"
            case .waveahand: "waveahand"
            case .induction: "induction"
            }
        }
    }

    /// Extension field flags used in HSv5 conclusion handshakes.
    public struct ExtensionFlags: OptionSet, Sendable, Hashable {
        /// The raw bitmask value.
        public let rawValue: UInt16

        /// Creates extension flags from a raw bitmask value.
        /// - Parameter rawValue: The raw bitmask value.
        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }

        /// Handshake request extension present.
        public static let hsreq = ExtensionFlags(rawValue: 0x0001)
        /// Key material request extension present.
        public static let kmreq = ExtensionFlags(rawValue: 0x0002)
        /// Configuration extension present.
        public static let config = ExtensionFlags(rawValue: 0x0004)
    }

    /// The size of the handshake CIF in bytes.
    public static let cifSize = 48

    /// The handshake version (4 for HSv4, 5 for HSv5).
    public let version: UInt32
    /// The encryption field (0=none, 2=AES-128, 3=AES-192, 4=AES-256).
    public let encryptionField: UInt16
    /// The extension field (HSv5 conclusion: bitmask of `ExtensionFlags`).
    public let extensionField: UInt16
    /// The initial packet sequence number.
    public let initialPacketSequenceNumber: SequenceNumber
    /// The maximum transmission unit size (typically 1500).
    public let maxTransmissionUnitSize: UInt32
    /// The maximum flow window size (typically 8192).
    public let maxFlowWindowSize: UInt32
    /// The handshake type.
    public let handshakeType: HandshakeType
    /// The SRT socket identifier.
    public let srtSocketID: UInt32
    /// The SYN cookie for connection verification.
    public let synCookie: UInt32
    /// The peer IP address (128-bit).
    public let peerIPAddress: SRTPeerAddress

    /// Creates a new handshake packet.
    ///
    /// - Parameters:
    ///   - version: The handshake version.
    ///   - encryptionField: The encryption field value.
    ///   - extensionField: The extension field value.
    ///   - initialPacketSequenceNumber: The initial packet sequence number.
    ///   - maxTransmissionUnitSize: The maximum transmission unit size.
    ///   - maxFlowWindowSize: The maximum flow window size.
    ///   - handshakeType: The handshake type.
    ///   - srtSocketID: The SRT socket identifier.
    ///   - synCookie: The SYN cookie.
    ///   - peerIPAddress: The peer IP address.
    public init(
        version: UInt32,
        encryptionField: UInt16 = 0,
        extensionField: UInt16 = 0,
        initialPacketSequenceNumber: SequenceNumber = SequenceNumber(0),
        maxTransmissionUnitSize: UInt32 = 1500,
        maxFlowWindowSize: UInt32 = 8192,
        handshakeType: HandshakeType,
        srtSocketID: UInt32,
        synCookie: UInt32 = 0,
        peerIPAddress: SRTPeerAddress = .ipv4(0)
    ) {
        self.version = version
        self.encryptionField = encryptionField
        self.extensionField = extensionField
        self.initialPacketSequenceNumber = initialPacketSequenceNumber
        self.maxTransmissionUnitSize = maxTransmissionUnitSize
        self.maxFlowWindowSize = maxFlowWindowSize
        self.handshakeType = handshakeType
        self.srtSocketID = srtSocketID
        self.synCookie = synCookie
        self.peerIPAddress = peerIPAddress
    }

    /// Encodes this handshake CIF into a buffer (48 bytes, big-endian).
    ///
    /// - Parameter buffer: The buffer to write into.
    public func encode(into buffer: inout ByteBuffer) {
        buffer.writeInteger(version)
        buffer.writeInteger(encryptionField)
        buffer.writeInteger(extensionField)
        buffer.writeInteger(initialPacketSequenceNumber.value)
        buffer.writeInteger(maxTransmissionUnitSize)
        buffer.writeInteger(maxFlowWindowSize)
        buffer.writeInteger(handshakeType.rawValue)
        buffer.writeInteger(srtSocketID)
        buffer.writeInteger(synCookie)
        peerIPAddress.encode(into: &buffer)
    }

    /// Decodes a handshake CIF from a buffer (reads exactly 48 bytes).
    ///
    /// - Parameter buffer: The buffer to read from.
    /// - Returns: The decoded handshake packet.
    /// - Throws: `SRTError.invalidPacket` if the buffer is too small or contains invalid data.
    public static func decode(from buffer: inout ByteBuffer) throws -> HandshakePacket {
        guard buffer.readableBytes >= cifSize else {
            throw SRTError.invalidPacket("Handshake CIF requires \(cifSize) bytes, got \(buffer.readableBytes)")
        }
        guard let version = buffer.readInteger(as: UInt32.self),
            let encryptionField = buffer.readInteger(as: UInt16.self),
            let extensionField = buffer.readInteger(as: UInt16.self),
            let initialSeq = buffer.readInteger(as: UInt32.self),
            let mtu = buffer.readInteger(as: UInt32.self),
            let flowWindow = buffer.readInteger(as: UInt32.self),
            let hsTypeRaw = buffer.readInteger(as: UInt32.self),
            let socketID = buffer.readInteger(as: UInt32.self),
            let cookie = buffer.readInteger(as: UInt32.self)
        else {
            throw SRTError.invalidPacket("Failed to read handshake CIF fields")
        }
        guard let hsType = HandshakeType(rawValue: hsTypeRaw) else {
            throw SRTError.invalidPacket("Unknown handshake type: 0x\(String(hsTypeRaw, radix: 16))")
        }
        let peerAddr = try SRTPeerAddress.decode(from: &buffer)

        return HandshakePacket(
            version: version,
            encryptionField: encryptionField,
            extensionField: extensionField,
            initialPacketSequenceNumber: SequenceNumber(initialSeq),
            maxTransmissionUnitSize: mtu,
            maxFlowWindowSize: flowWindow,
            handshakeType: hsType,
            srtSocketID: socketID,
            synCookie: cookie,
            peerIPAddress: peerAddr
        )
    }
}
