// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("HandshakePacketEncoder Coverage Tests")
struct HandshakePacketEncoderCoverageTests {

    // MARK: - Unknown extension type skipped during decode

    @Test("Decode skips extension with unknown type ID")
    func decodeUnknownExtensionType() throws {
        var buffer = ByteBuffer()

        // Write an extension with unknown type 0xFFFF, length 1 word (4 bytes)
        buffer.writeInteger(UInt16(0xFFFF))  // unknown type
        buffer.writeInteger(UInt16(1))  // 1 word = 4 bytes
        buffer.writeBytes([0xDE, 0xAD, 0xBE, 0xEF])  // 4 bytes content

        // Write a valid HSREQ extension after the unknown one
        let hsreqType = HandshakeExtensionType.srtHandshakeRequest.rawValue
        let hsreqLengthWords = UInt16(SRTHandshakeExtension.encodedSize / 4)
        buffer.writeInteger(hsreqType)
        buffer.writeInteger(hsreqLengthWords)

        var hsreqContent = ByteBuffer()
        let hsreq = SRTHandshakeExtension(
            srtVersion: 0x0001_0501,
            srtFlags: [.tsbpdSender],
            receiverTSBPDDelay: 100,
            senderTSBPDDelay: 200
        )
        hsreq.encode(into: &hsreqContent)
        buffer.writeBuffer(&hsreqContent)

        let extensions = try HandshakePacketEncoder.decodeExtensions(from: &buffer)
        // Unknown extension should be skipped, only HSREQ should remain
        #expect(extensions.count == 1)
        if case .hsreq(let ext) = extensions[0] {
            #expect(ext.srtVersion == 0x0001_0501)
            #expect(ext.receiverTSBPDDelay == 100)
            #expect(ext.senderTSBPDDelay == 200)
        } else {
            Issue.record("Expected HSREQ extension")
        }
    }

    @Test("Decode with only unknown extensions returns empty array")
    func decodeOnlyUnknownExtensions() throws {
        var buffer = ByteBuffer()

        // Unknown type 0x00FF, 2 words
        buffer.writeInteger(UInt16(0x00FF))
        buffer.writeInteger(UInt16(2))
        buffer.writeBytes(Array(repeating: UInt8(0), count: 8))

        let extensions = try HandshakePacketEncoder.decodeExtensions(from: &buffer)
        #expect(extensions.isEmpty)
    }

    // MARK: - Buffer ending mid-header (< 4 bytes remaining)

    @Test("Decode with zero bytes remaining returns empty array")
    func decodeEmptyBuffer() throws {
        var buffer = ByteBuffer()
        let extensions = try HandshakePacketEncoder.decodeExtensions(from: &buffer)
        #expect(extensions.isEmpty)
    }

    @Test("Decode with 1 byte remaining returns empty array (not enough for header)")
    func decode1ByteBuffer() throws {
        var buffer = ByteBuffer()
        buffer.writeInteger(UInt8(0x01))
        let extensions = try HandshakePacketEncoder.decodeExtensions(from: &buffer)
        #expect(extensions.isEmpty)
    }

    @Test("Decode with 2 bytes remaining returns empty array")
    func decode2ByteBuffer() throws {
        var buffer = ByteBuffer()
        buffer.writeInteger(UInt16(0x0001))
        let extensions = try HandshakePacketEncoder.decodeExtensions(from: &buffer)
        #expect(extensions.isEmpty)
    }

    @Test("Decode with 3 bytes remaining returns empty array")
    func decode3ByteBuffer() throws {
        var buffer = ByteBuffer()
        buffer.writeInteger(UInt16(0x0001))
        buffer.writeInteger(UInt8(0x00))
        let extensions = try HandshakePacketEncoder.decodeExtensions(from: &buffer)
        #expect(extensions.isEmpty)
    }

    @Test("Decode with header but content truncated throws error")
    func decodeHeaderButContentTruncated() throws {
        var buffer = ByteBuffer()
        // Valid HSREQ type, 3 words = 12 bytes content, but only 4 bytes provided
        buffer.writeInteger(HandshakeExtensionType.srtHandshakeRequest.rawValue)
        buffer.writeInteger(UInt16(3))  // 3 words = 12 bytes
        buffer.writeBytes([0x00, 0x01, 0x05, 0x01])  // only 4 bytes, need 12

        #expect(throws: SRTError.self) {
            _ = try HandshakePacketEncoder.decodeExtensions(from: &buffer)
        }
    }

    // MARK: - Encode extensions with various padding sizes

    @Test("Encode StreamID with 1-byte content (3 bytes padding)")
    func encodeStreamID1Byte() throws {
        let packet = HandshakePacket(
            version: 5,
            extensionField: HandshakePacket.ExtensionFlags.config.rawValue,
            handshakeType: .conclusion,
            srtSocketID: 0x1111
        )

        var buffer = HandshakePacketEncoder.encode(
            handshake: packet,
            extensions: [.streamID("A")],
            destinationSocketID: 0,
            timestamp: 0
        )

        let srtPacket = try PacketCodec.decode(from: &buffer)
        guard case .control(let control) = srtPacket else {
            Issue.record("Expected control packet")
            return
        }

        var cifBuf = ByteBuffer(bytes: control.controlInfoField)
        _ = try HandshakePacket.decode(from: &cifBuf)
        let extensions = try HandshakePacketEncoder.decodeExtensions(from: &cifBuf)
        #expect(extensions.count == 1)
        if case .streamID(let sid) = extensions[0] {
            #expect(sid == "A")
        } else {
            Issue.record("Expected StreamID extension")
        }
    }

    @Test("Encode StreamID with 2-byte content (2 bytes padding)")
    func encodeStreamID2Bytes() throws {
        let packet = HandshakePacket(
            version: 5,
            extensionField: HandshakePacket.ExtensionFlags.config.rawValue,
            handshakeType: .conclusion,
            srtSocketID: 0x2222
        )

        var buffer = HandshakePacketEncoder.encode(
            handshake: packet,
            extensions: [.streamID("AB")],
            destinationSocketID: 0,
            timestamp: 0
        )

        let srtPacket = try PacketCodec.decode(from: &buffer)
        guard case .control(let control) = srtPacket else {
            Issue.record("Expected control packet")
            return
        }

        var cifBuf = ByteBuffer(bytes: control.controlInfoField)
        _ = try HandshakePacket.decode(from: &cifBuf)
        let extensions = try HandshakePacketEncoder.decodeExtensions(from: &cifBuf)
        #expect(extensions.count == 1)
        if case .streamID(let sid) = extensions[0] {
            #expect(sid == "AB")
        } else {
            Issue.record("Expected StreamID extension")
        }
    }

    @Test("Encode StreamID with 3-byte content (1 byte padding)")
    func encodeStreamID3Bytes() throws {
        let packet = HandshakePacket(
            version: 5,
            extensionField: HandshakePacket.ExtensionFlags.config.rawValue,
            handshakeType: .conclusion,
            srtSocketID: 0x3333
        )

        var buffer = HandshakePacketEncoder.encode(
            handshake: packet,
            extensions: [.streamID("ABC")],
            destinationSocketID: 0,
            timestamp: 0
        )

        let srtPacket = try PacketCodec.decode(from: &buffer)
        guard case .control(let control) = srtPacket else {
            Issue.record("Expected control packet")
            return
        }

        var cifBuf = ByteBuffer(bytes: control.controlInfoField)
        _ = try HandshakePacket.decode(from: &cifBuf)
        let extensions = try HandshakePacketEncoder.decodeExtensions(from: &cifBuf)
        #expect(extensions.count == 1)
        if case .streamID(let sid) = extensions[0] {
            #expect(sid == "ABC")
        } else {
            Issue.record("Expected StreamID extension")
        }
    }

    @Test("Encode StreamID with 4-byte content (0 bytes padding)")
    func encodeStreamID4Bytes() throws {
        let packet = HandshakePacket(
            version: 5,
            extensionField: HandshakePacket.ExtensionFlags.config.rawValue,
            handshakeType: .conclusion,
            srtSocketID: 0x4444
        )

        var buffer = HandshakePacketEncoder.encode(
            handshake: packet,
            extensions: [.streamID("ABCD")],
            destinationSocketID: 0,
            timestamp: 0
        )

        let srtPacket = try PacketCodec.decode(from: &buffer)
        guard case .control(let control) = srtPacket else {
            Issue.record("Expected control packet")
            return
        }

        var cifBuf = ByteBuffer(bytes: control.controlInfoField)
        _ = try HandshakePacket.decode(from: &cifBuf)
        let extensions = try HandshakePacketEncoder.decodeExtensions(from: &cifBuf)
        #expect(extensions.count == 1)
        if case .streamID(let sid) = extensions[0] {
            #expect(sid == "ABCD")
        } else {
            Issue.record("Expected StreamID extension")
        }
    }

}

@Suite("HandshakePacketEncoder Coverage Tests Part 2")
struct HandshakePacketEncoderCoverageTests2 {

    // MARK: - Encode KMRSP extension

    @Test("Encode and decode KMRSP extension roundtrip")
    func encodeKMRSP() throws {
        let km = KeyMaterialPacket(
            cipher: .aesCTR,
            salt: Array(repeating: 0xCC, count: 16),
            keyLength: 16,
            wrappedKeys: Array(repeating: 0xDD, count: 24)
        )
        let packet = HandshakePacket(
            version: 5,
            extensionField: HandshakePacket.ExtensionFlags.kmreq.rawValue,
            handshakeType: .conclusion,
            srtSocketID: 0x5555
        )

        var buffer = HandshakePacketEncoder.encode(
            handshake: packet,
            extensions: [.kmrsp(km)],
            destinationSocketID: 0xAAAA,
            timestamp: 100
        )

        let srtPacket = try PacketCodec.decode(from: &buffer)
        guard case .control(let control) = srtPacket else {
            Issue.record("Expected control packet")
            return
        }

        var cifBuf = ByteBuffer(bytes: control.controlInfoField)
        _ = try HandshakePacket.decode(from: &cifBuf)
        let extensions = try HandshakePacketEncoder.decodeExtensions(from: &cifBuf)
        #expect(extensions.count == 1)
        if case .kmrsp(let decoded) = extensions[0] {
            #expect(decoded.cipher == .aesCTR)
            #expect(decoded.keyLength == 16)
            #expect(decoded.salt.count == 16)
            #expect(decoded.salt.allSatisfy { $0 == 0xCC })
        } else {
            Issue.record("Expected KMRSP extension")
        }
    }

    @Test("Encode KMREQ extension roundtrip")
    func encodeKMREQ() throws {
        let km = KeyMaterialPacket(
            cipher: .aesGCM,
            salt: Array(repeating: 0xAA, count: 16),
            keyLength: 32,
            wrappedKeys: Array(repeating: 0xBB, count: 40)
        )
        let packet = HandshakePacket(
            version: 5,
            extensionField: HandshakePacket.ExtensionFlags.kmreq.rawValue,
            handshakeType: .conclusion,
            srtSocketID: 0x6666
        )

        var buffer = HandshakePacketEncoder.encode(
            handshake: packet,
            extensions: [.kmreq(km)],
            destinationSocketID: 0xBBBB,
            timestamp: 200
        )

        let srtPacket = try PacketCodec.decode(from: &buffer)
        guard case .control(let control) = srtPacket else {
            Issue.record("Expected control packet")
            return
        }

        var cifBuf = ByteBuffer(bytes: control.controlInfoField)
        _ = try HandshakePacket.decode(from: &cifBuf)
        let extensions = try HandshakePacketEncoder.decodeExtensions(from: &cifBuf)
        #expect(extensions.count == 1)
        if case .kmreq(let decoded) = extensions[0] {
            #expect(decoded.cipher == .aesGCM)
            #expect(decoded.keyLength == 32)
        } else {
            Issue.record("Expected KMREQ extension")
        }
    }

    // MARK: - extensionTypeID for KMRSP

    @Test("extensionTypeID returns kmResponse for kmrsp")
    func extensionTypeIDKMRSP() {
        let km = KeyMaterialPacket(
            cipher: .aesCTR,
            salt: Array(repeating: 0, count: 16),
            keyLength: 16,
            wrappedKeys: Array(repeating: 0, count: 24)
        )
        let typeID = HandshakePacketEncoder.extensionTypeID(for: .kmrsp(km))
        #expect(typeID == .kmResponse)
    }

    @Test("extensionTypeID returns kmRequest for kmreq")
    func extensionTypeIDKMREQ() {
        let km = KeyMaterialPacket(
            cipher: .aesCTR,
            salt: Array(repeating: 0, count: 16),
            keyLength: 16,
            wrappedKeys: Array(repeating: 0, count: 24)
        )
        let typeID = HandshakePacketEncoder.extensionTypeID(for: .kmreq(km))
        #expect(typeID == .kmRequest)
    }

    @Test("extensionTypeID returns srtHandshakeResponse for hsrsp")
    func extensionTypeIDHSRSP() {
        let hsrsp = SRTHandshakeExtension(
            srtVersion: 0, srtFlags: [],
            receiverTSBPDDelay: 0, senderTSBPDDelay: 0
        )
        let typeID = HandshakePacketEncoder.extensionTypeID(for: .hsrsp(hsrsp))
        #expect(typeID == .srtHandshakeResponse)
    }

    // MARK: - Decode congestion/filter/group extensions (skipped)

    @Test("Decode skips congestion extension type")
    func decodeCongestionExtension() throws {
        var buffer = ByteBuffer()
        // Congestion type = 0x0006, 1 word
        buffer.writeInteger(HandshakeExtensionType.congestion.rawValue)
        buffer.writeInteger(UInt16(1))
        buffer.writeBytes([0x00, 0x00, 0x00, 0x01])

        let extensions = try HandshakePacketEncoder.decodeExtensions(from: &buffer)
        #expect(extensions.isEmpty)
    }

    @Test("Decode skips filter extension type")
    func decodeFilterExtension() throws {
        var buffer = ByteBuffer()
        // Filter type = 0x0007, 1 word
        buffer.writeInteger(HandshakeExtensionType.filter.rawValue)
        buffer.writeInteger(UInt16(1))
        buffer.writeBytes([0x00, 0x00, 0x00, 0x02])

        let extensions = try HandshakePacketEncoder.decodeExtensions(from: &buffer)
        #expect(extensions.isEmpty)
    }

    @Test("Decode skips group extension type")
    func decodeGroupExtension() throws {
        var buffer = ByteBuffer()
        // Group type = 0x0008, 1 word
        buffer.writeInteger(HandshakeExtensionType.group.rawValue)
        buffer.writeInteger(UInt16(1))
        buffer.writeBytes([0x00, 0x00, 0x00, 0x03])

        let extensions = try HandshakePacketEncoder.decodeExtensions(from: &buffer)
        #expect(extensions.isEmpty)
    }
}
