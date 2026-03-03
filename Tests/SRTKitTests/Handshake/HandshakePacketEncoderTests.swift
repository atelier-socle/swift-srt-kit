// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("HandshakePacketEncoder Tests")
struct HandshakePacketEncoderTests {

    @Test("Roundtrip encode/decode with no extensions")
    func roundtripNoExtensions() throws {
        let packet = HandshakePacket(
            version: 5,
            encryptionField: 0,
            extensionField: 0,
            handshakeType: .induction,
            srtSocketID: 0x1234
        )

        var buffer = HandshakePacketEncoder.encode(
            handshake: packet,
            extensions: [],
            destinationSocketID: 0xABCD,
            timestamp: 1000
        )

        // Decode: skip 16-byte control header
        let srtPacket = try PacketCodec.decode(from: &buffer)
        guard case .control(let control) = srtPacket else {
            Issue.record("Expected control packet")
            return
        }
        #expect(control.controlType == .handshake)
        #expect(control.destinationSocketID == 0xABCD)

        var cifBuf = ByteBuffer(bytes: control.controlInfoField)
        let decoded = try HandshakePacket.decode(from: &cifBuf)
        #expect(decoded.version == 5)
        #expect(decoded.handshakeType == .induction)
        #expect(decoded.srtSocketID == 0x1234)
    }

    @Test("Roundtrip encode/decode HSREQ extension")
    func roundtripHSREQ() throws {
        let hsreq = SRTHandshakeExtension(
            srtVersion: 0x0001_0501,
            srtFlags: [.tsbpdSender, .tsbpdReceiver],
            receiverTSBPDDelay: 120,
            senderTSBPDDelay: 120
        )
        let packet = HandshakePacket(
            version: 5,
            extensionField: HandshakePacket.ExtensionFlags.hsreq.rawValue,
            handshakeType: .conclusion,
            srtSocketID: 0x5678,
            synCookie: 0xDEAD
        )

        var buffer = HandshakePacketEncoder.encode(
            handshake: packet,
            extensions: [.hsreq(hsreq)],
            destinationSocketID: 0,
            timestamp: 0
        )

        let srtPacket = try PacketCodec.decode(from: &buffer)
        guard case .control(let control) = srtPacket else {
            Issue.record("Expected control packet")
            return
        }

        var cifBuf = ByteBuffer(bytes: control.controlInfoField)
        let decoded = try HandshakePacket.decode(from: &cifBuf)
        #expect(decoded.handshakeType == .conclusion)

        let extensions = try HandshakePacketEncoder.decodeExtensions(from: &cifBuf)
        #expect(extensions.count == 1)
        if case .hsreq(let ext) = extensions[0] {
            #expect(ext.srtVersion == 0x0001_0501)
            #expect(ext.receiverTSBPDDelay == 120)
            #expect(ext.senderTSBPDDelay == 120)
        } else {
            Issue.record("Expected HSREQ extension")
        }
    }

    @Test("Roundtrip encode/decode StreamID extension")
    func roundtripStreamID() throws {
        let packet = HandshakePacket(
            version: 5,
            extensionField: HandshakePacket.ExtensionFlags.config.rawValue,
            handshakeType: .conclusion,
            srtSocketID: 0x9999
        )

        var buffer = HandshakePacketEncoder.encode(
            handshake: packet,
            extensions: [.streamID("#!::r=live/test,m=publish")],
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
            #expect(sid == "#!::r=live/test,m=publish")
        } else {
            Issue.record("Expected StreamID extension")
        }
    }

    @Test("Roundtrip encode/decode multiple extensions")
    func roundtripMultipleExtensions() throws {
        let hsrsp = SRTHandshakeExtension(
            srtVersion: 0x0001_0501,
            srtFlags: [.tsbpdSender, .tsbpdReceiver, .tlpktDrop],
            receiverTSBPDDelay: 200,
            senderTSBPDDelay: 200
        )
        let km = KeyMaterialPacket(
            cipher: .aesCTR,
            salt: Array(repeating: 0xAA, count: 16),
            keyLength: 16,
            wrappedKeys: Array(repeating: 0xBB, count: 24)
        )
        let packet = HandshakePacket(
            version: 5,
            extensionField: 0x0003,
            handshakeType: .conclusion,
            srtSocketID: 0x1111
        )

        var buffer = HandshakePacketEncoder.encode(
            handshake: packet,
            extensions: [.hsrsp(hsrsp), .kmrsp(km)],
            destinationSocketID: 0x2222,
            timestamp: 5000
        )

        let srtPacket = try PacketCodec.decode(from: &buffer)
        guard case .control(let control) = srtPacket else {
            Issue.record("Expected control packet")
            return
        }

        var cifBuf = ByteBuffer(bytes: control.controlInfoField)
        _ = try HandshakePacket.decode(from: &cifBuf)

        let extensions = try HandshakePacketEncoder.decodeExtensions(from: &cifBuf)
        #expect(extensions.count == 2)

        if case .hsrsp(let ext) = extensions[0] {
            #expect(ext.receiverTSBPDDelay == 200)
        } else {
            Issue.record("Expected HSRSP extension first")
        }

        if case .kmrsp(let kmExt) = extensions[1] {
            #expect(kmExt.cipher == .aesCTR)
        } else {
            Issue.record("Expected KMRSP extension second")
        }
    }

    @Test("extensionTypeID maps correctly")
    func extensionTypeIDMapping() {
        #expect(
            HandshakePacketEncoder.extensionTypeID(
                for: .hsreq(
                    SRTHandshakeExtension(
                        srtVersion: 0, srtFlags: [],
                        receiverTSBPDDelay: 0, senderTSBPDDelay: 0)
                )) == .srtHandshakeRequest
        )
        #expect(
            HandshakePacketEncoder.extensionTypeID(
                for: .streamID("test")
            ) == .streamID
        )
    }
}
