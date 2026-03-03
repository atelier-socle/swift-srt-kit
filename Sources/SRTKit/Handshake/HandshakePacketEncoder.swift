// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore

/// Composes and decomposes wire-ready SRT handshake control packets.
///
/// Bridges the gap between the handshake state machine (which produces
/// ``HandshakeAction/sendPacket(_:extensions:)``) and the transport layer
/// (which sends raw ``ByteBuffer``). Handles the 16-byte SRT control header,
/// 48-byte CIF, and variable-length extension TLV blocks.
public enum HandshakePacketEncoder: Sendable {

    /// Encode a handshake packet with extensions into a wire-ready buffer.
    ///
    /// Layout: `[16-byte control header][48-byte CIF][extension TLVs...]`
    ///
    /// - Parameters:
    ///   - handshake: The 48-byte handshake CIF.
    ///   - extensions: Extension data to append after the CIF.
    ///   - destinationSocketID: The destination socket ID for the control header.
    ///   - timestamp: The control packet timestamp.
    /// - Returns: A wire-ready ByteBuffer.
    public static func encode(
        handshake: HandshakePacket,
        extensions: [HandshakeExtensionData],
        destinationSocketID: UInt32,
        timestamp: UInt32 = 0
    ) -> ByteBuffer {
        var buffer = ByteBuffer()
        buffer.reserveCapacity(16 + HandshakePacket.cifSize + extensions.count * 20)

        // 16-byte control header via PacketCodec helper
        PacketCodec.encode(
            controlType: .handshake,
            timestamp: timestamp,
            destinationSocketID: destinationSocketID,
            cif: .handshake(handshake),
            into: &buffer
        )

        // Append extension TLVs after the CIF
        for ext in extensions {
            encodeExtension(ext, into: &buffer)
        }

        return buffer
    }

    /// Decode extensions from a buffer positioned after the 48-byte handshake CIF.
    ///
    /// - Parameter buffer: Buffer with reader index at the first extension header.
    /// - Returns: Array of decoded extension data.
    /// - Throws: ``SRTError/invalidPacket(_:)`` on malformed data.
    public static func decodeExtensions(
        from buffer: inout ByteBuffer
    ) throws -> [HandshakeExtensionData] {
        var results: [HandshakeExtensionData] = []

        while buffer.readableBytes >= 4 {
            let header = try HandshakeExtensionHeader.decode(from: &buffer)
            let contentLen = header.contentLengthBytes

            guard buffer.readableBytes >= contentLen else {
                throw SRTError.invalidPacket(
                    "Extension content requires \(contentLen) bytes, got \(buffer.readableBytes)"
                )
            }

            guard let extType = HandshakeExtensionType(rawValue: header.extensionType) else {
                // Skip unknown extensions
                buffer.moveReaderIndex(forwardBy: contentLen)
                continue
            }

            switch extType {
            case .srtHandshakeRequest:
                let hsreq = try SRTHandshakeExtension.decode(from: &buffer)
                results.append(.hsreq(hsreq))

            case .srtHandshakeResponse:
                let hsrsp = try SRTHandshakeExtension.decode(from: &buffer)
                results.append(.hsrsp(hsrsp))

            case .kmRequest:
                let km = try KeyMaterialPacket.decode(from: &buffer, cifLength: contentLen)
                results.append(.kmreq(km))

            case .kmResponse:
                let km = try KeyMaterialPacket.decode(from: &buffer, cifLength: contentLen)
                results.append(.kmrsp(km))

            case .streamID:
                let sid = try StreamIDExtension.decode(from: &buffer, length: contentLen)
                results.append(.streamID(sid.streamID))

            case .congestion, .filter, .group:
                buffer.moveReaderIndex(forwardBy: contentLen)
            }
        }

        return results
    }

    /// Maps a ``HandshakeExtensionData`` case to its extension type ID.
    ///
    /// - Parameter ext: The extension data.
    /// - Returns: The wire type identifier.
    public static func extensionTypeID(
        for ext: HandshakeExtensionData
    ) -> HandshakeExtensionType {
        switch ext {
        case .hsreq: .srtHandshakeRequest
        case .hsrsp: .srtHandshakeResponse
        case .kmreq: .kmRequest
        case .kmrsp: .kmResponse
        case .streamID: .streamID
        }
    }

    // MARK: - Private

    /// Encode a single extension as a TLV (type-length-value) block.
    private static func encodeExtension(
        _ ext: HandshakeExtensionData,
        into buffer: inout ByteBuffer
    ) {
        // Write content to a temporary buffer to measure length
        var content = ByteBuffer()

        switch ext {
        case .hsreq(let hs), .hsrsp(let hs):
            hs.encode(into: &content)

        case .kmreq(let km), .kmrsp(let km):
            km.encode(into: &content)

        case .streamID(let sid):
            let sidExt = StreamIDExtension(streamID: sid)
            sidExt.encode(into: &content)
        }

        let contentBytes = content.readableBytes
        let lengthInWords = UInt16((contentBytes + 3) / 4)
        let paddedLength = Int(lengthInWords) * 4
        let padding = paddedLength - contentBytes

        let typeID = extensionTypeID(for: ext)
        let header = HandshakeExtensionHeader(
            extensionType: typeID.rawValue,
            extensionLength: lengthInWords
        )
        header.encode(into: &buffer)
        buffer.writeBuffer(&content)
        // Pad to 4-byte boundary
        for _ in 0..<padding {
            buffer.writeInteger(UInt8(0))
        }
    }
}
