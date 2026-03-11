// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore

/// Extension type identifiers for SRT handshake extensions.
///
/// Extensions are appended after the 48-byte handshake CIF in CONCLUSION packets.
public enum HandshakeExtensionType: UInt16, Sendable, Hashable, CaseIterable, CustomStringConvertible {
    /// SRT handshake request (HSREQ).
    case srtHandshakeRequest = 0x0001
    /// SRT handshake response (HSRSP).
    case srtHandshakeResponse = 0x0002
    /// Key material request (KMREQ).
    case kmRequest = 0x0003
    /// Key material response (KMRSP).
    case kmResponse = 0x0004
    /// Stream ID (SID).
    case streamID = 0x0005
    /// Congestion controller (SMOOTHER).
    case congestion = 0x0006
    /// Packet filter configuration (FILTER/FEC).
    case filter = 0x0007
    /// Connection group (GROUP).
    case group = 0x0008

    /// A human-readable description of the extension type.
    public var description: String {
        switch self {
        case .srtHandshakeRequest: "HSREQ"
        case .srtHandshakeResponse: "HSRSP"
        case .kmRequest: "KMREQ"
        case .kmResponse: "KMRSP"
        case .streamID: "SID"
        case .congestion: "SMOOTHER"
        case .filter: "FILTER"
        case .group: "GROUP"
        }
    }
}

/// A generic handshake extension header.
///
/// Wire format: `[type: UInt16][length: UInt16 (in 4-byte words)]`
public struct HandshakeExtensionHeader: Sendable, Equatable {
    /// The extension type identifier.
    public let extensionType: UInt16
    /// The extension content length in 4-byte words.
    public let extensionLength: UInt16

    /// The content length in bytes.
    public var contentLengthBytes: Int { Int(extensionLength) * 4 }

    /// Creates a new handshake extension header.
    ///
    /// - Parameters:
    ///   - extensionType: The extension type identifier.
    ///   - extensionLength: The content length in 4-byte words.
    public init(extensionType: UInt16, extensionLength: UInt16) {
        self.extensionType = extensionType
        self.extensionLength = extensionLength
    }

    /// Encodes this header into a buffer (4 bytes).
    ///
    /// - Parameter buffer: The buffer to write into.
    public func encode(into buffer: inout ByteBuffer) {
        buffer.writeInteger(extensionType)
        buffer.writeInteger(extensionLength)
    }

    /// Decodes an extension header from a buffer.
    ///
    /// - Parameter buffer: The buffer to read from.
    /// - Returns: The decoded header.
    /// - Throws: `SRTError.invalidPacket` if the buffer is too small.
    public static func decode(from buffer: inout ByteBuffer) throws -> HandshakeExtensionHeader {
        guard buffer.readableBytes >= 4 else {
            throw SRTError.invalidPacket("Extension header requires 4 bytes, got \(buffer.readableBytes)")
        }
        guard let extType = buffer.readInteger(as: UInt16.self),
            let extLen = buffer.readInteger(as: UInt16.self)
        else {
            throw SRTError.invalidPacket("Failed to read extension header")
        }
        return HandshakeExtensionHeader(extensionType: extType, extensionLength: extLen)
    }
}

/// SRT capability flags used in HSREQ/HSRSP extensions.
public struct SRTFlags: OptionSet, Sendable, Hashable {
    /// The raw bitmask value.
    public let rawValue: UInt32

    /// Creates SRT flags from a raw bitmask value.
    /// - Parameter rawValue: The raw bitmask value.
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Sender supports TSBPD (Timestamp-Based Packet Delivery).
    public static let tsbpdSender = SRTFlags(rawValue: 1 << 0)
    /// Receiver supports TSBPD.
    public static let tsbpdReceiver = SRTFlags(rawValue: 1 << 1)
    /// Encryption is enabled.
    public static let crypt = SRTFlags(rawValue: 1 << 2)
    /// Too-Late Packet Drop is enabled.
    public static let tlpktDrop = SRTFlags(rawValue: 1 << 3)
    /// Periodic NAK reports are enabled.
    public static let periodicNAK = SRTFlags(rawValue: 1 << 4)
    /// Retransmission flag in data packets is used.
    public static let rexmitFlag = SRTFlags(rawValue: 1 << 5)
    /// Stream mode (vs message mode).
    public static let stream = SRTFlags(rawValue: 1 << 6)
    /// Packet filter is enabled.
    public static let packetFilter = SRTFlags(rawValue: 1 << 7)
}

/// SRT handshake extension (HSREQ/HSRSP) containing version, flags, and TSBPD delays.
///
/// Wire format: 12 bytes (3 x UInt32 words).
public struct SRTHandshakeExtension: Sendable, Equatable {
    /// The encoded size in bytes.
    public static let encodedSize = 12

    /// The SRT version (e.g., `0x010501` for v1.5.1).
    public let srtVersion: UInt32
    /// The SRT capability flags.
    public let srtFlags: SRTFlags
    /// The receiver TSBPD delay in milliseconds.
    public let receiverTSBPDDelay: UInt16
    /// The sender TSBPD delay in milliseconds.
    public let senderTSBPDDelay: UInt16

    /// Creates a new SRT handshake extension.
    ///
    /// - Parameters:
    ///   - srtVersion: The SRT version.
    ///   - srtFlags: The SRT capability flags.
    ///   - receiverTSBPDDelay: The receiver TSBPD delay in milliseconds.
    ///   - senderTSBPDDelay: The sender TSBPD delay in milliseconds.
    public init(
        srtVersion: UInt32,
        srtFlags: SRTFlags,
        receiverTSBPDDelay: UInt16,
        senderTSBPDDelay: UInt16
    ) {
        self.srtVersion = srtVersion
        self.srtFlags = srtFlags
        self.receiverTSBPDDelay = receiverTSBPDDelay
        self.senderTSBPDDelay = senderTSBPDDelay
    }

    /// Encodes this extension into a buffer (12 bytes).
    ///
    /// - Parameter buffer: The buffer to write into.
    public func encode(into buffer: inout ByteBuffer) {
        buffer.writeInteger(srtVersion)
        buffer.writeInteger(srtFlags.rawValue)
        buffer.writeInteger(receiverTSBPDDelay)
        buffer.writeInteger(senderTSBPDDelay)
    }

    /// Decodes an SRT handshake extension from a buffer.
    ///
    /// - Parameter buffer: The buffer to read from.
    /// - Returns: The decoded extension.
    /// - Throws: `SRTError.invalidPacket` if the buffer is too small.
    public static func decode(from buffer: inout ByteBuffer) throws -> SRTHandshakeExtension {
        guard buffer.readableBytes >= encodedSize else {
            throw SRTError.invalidPacket("SRT HS extension requires \(encodedSize) bytes, got \(buffer.readableBytes)")
        }
        guard let version = buffer.readInteger(as: UInt32.self),
            let flags = buffer.readInteger(as: UInt32.self),
            let recvDelay = buffer.readInteger(as: UInt16.self),
            let sendDelay = buffer.readInteger(as: UInt16.self)
        else {
            throw SRTError.invalidPacket("Failed to read SRT HS extension fields")
        }
        return SRTHandshakeExtension(
            srtVersion: version,
            srtFlags: SRTFlags(rawValue: flags),
            receiverTSBPDDelay: recvDelay,
            senderTSBPDDelay: sendDelay
        )
    }
}

/// A Stream ID handshake extension carrying a UTF-8 string.
///
/// The content is null-padded to a 4-byte boundary. Each 4-byte chunk
/// is written as a UInt32 word with the first string byte in the
/// least-significant position. This matches the SRT wire format where
/// libsrt treats extension content as 32-bit words in network byte order,
/// effectively inverting the bytes within each 4-byte group.
///
/// Maximum stream ID length is 512 bytes.
public struct StreamIDExtension: Sendable, Equatable {
    /// The maximum stream ID length in bytes.
    public static let maxLength = 512

    /// The stream ID string.
    public let streamID: String

    /// Creates a new stream ID extension.
    ///
    /// - Parameter streamID: The stream ID string (max 512 bytes UTF-8).
    public init(streamID: String) {
        self.streamID = streamID
    }

    /// Encodes this extension into a buffer, padded to a 4-byte boundary.
    ///
    /// Each 4-byte chunk is written as a UInt32 word with the first
    /// string byte in the least-significant position (SRT wire format).
    ///
    /// - Parameter buffer: The buffer to write into.
    public func encode(into buffer: inout ByteBuffer) {
        var bytes = Array(streamID.utf8)
        let padding = (4 - (bytes.count % 4)) % 4
        bytes.append(contentsOf: repeatElement(UInt8(0), count: padding))
        for i in stride(from: 0, to: bytes.count, by: 4) {
            let word =
                UInt32(bytes[i])
                | UInt32(bytes[i + 1]) << 8
                | UInt32(bytes[i + 2]) << 16
                | UInt32(bytes[i + 3]) << 24
            buffer.writeInteger(word)
        }
    }

    /// Decodes a stream ID extension from a buffer.
    ///
    /// Each 4-byte chunk is read as a UInt32 word with the first
    /// string byte in the least-significant position (SRT wire format).
    ///
    /// - Parameters:
    ///   - buffer: The buffer to read from.
    ///   - length: The total content length in bytes (including padding).
    /// - Returns: The decoded stream ID extension.
    /// - Throws: `SRTError.invalidPacket` if the buffer is too small or the string is invalid.
    public static func decode(from buffer: inout ByteBuffer, length: Int) throws -> StreamIDExtension {
        guard buffer.readableBytes >= length else {
            throw SRTError.invalidPacket(
                "StreamID requires \(length) bytes, got \(buffer.readableBytes)")
        }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(length)
        for _ in 0..<(length / 4) {
            guard let word = buffer.readInteger(as: UInt32.self) else {
                throw SRTError.invalidPacket("Failed to read StreamID word")
            }
            bytes.append(UInt8(truncatingIfNeeded: word))
            bytes.append(UInt8(truncatingIfNeeded: word >> 8))
            bytes.append(UInt8(truncatingIfNeeded: word >> 16))
            bytes.append(UInt8(truncatingIfNeeded: word >> 24))
        }
        // Remove trailing null padding
        let trimmed = Array(bytes.prefix { $0 != 0 })
        let str = String(decoding: trimmed, as: UTF8.self)
        return StreamIDExtension(streamID: str)
    }
}
