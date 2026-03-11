// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("HandshakeExtension Tests")
struct HandshakeExtensionTests {
    // MARK: - SRTHandshakeExtension

    @Test("HSREQ encode/decode roundtrip")
    func hsreqRoundtrip() throws {
        let original = SRTHandshakeExtension(
            srtVersion: 0x0001_0501,
            srtFlags: [.tsbpdSender, .tsbpdReceiver, .tlpktDrop, .periodicNAK, .rexmitFlag],
            receiverTSBPDDelay: 120,
            senderTSBPDDelay: 120
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        original.encode(into: &buffer)
        let decoded = try SRTHandshakeExtension.decode(from: &buffer)
        #expect(decoded == original)
    }

    @Test("HSRSP encode/decode (same structure)")
    func hsrspRoundtrip() throws {
        let original = SRTHandshakeExtension(
            srtVersion: 0x0001_0402,
            srtFlags: [.tsbpdSender, .crypt],
            receiverTSBPDDelay: 200,
            senderTSBPDDelay: 150
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        original.encode(into: &buffer)
        let decoded = try SRTHandshakeExtension.decode(from: &buffer)
        #expect(decoded == original)
    }

    @Test("SRT version encoding (0x010501)")
    func srtVersionEncoding() throws {
        let ext = SRTHandshakeExtension(
            srtVersion: 0x0001_0501,
            srtFlags: [],
            receiverTSBPDDelay: 0,
            senderTSBPDDelay: 0
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        ext.encode(into: &buffer)
        let firstWord = buffer.getInteger(at: 0, as: UInt32.self)
        #expect(firstWord == 0x0001_0501)
    }

    @Test("All SRTFlags individual values")
    func srtFlagsValues() {
        #expect(SRTFlags.tsbpdSender.rawValue == 1)
        #expect(SRTFlags.tsbpdReceiver.rawValue == 2)
        #expect(SRTFlags.crypt.rawValue == 4)
        #expect(SRTFlags.tlpktDrop.rawValue == 8)
        #expect(SRTFlags.periodicNAK.rawValue == 16)
        #expect(SRTFlags.rexmitFlag.rawValue == 32)
        #expect(SRTFlags.stream.rawValue == 64)
        #expect(SRTFlags.packetFilter.rawValue == 128)
    }

    @Test("SRTFlags combination roundtrip")
    func srtFlagsCombination() throws {
        let flags: SRTFlags = [.tsbpdSender, .crypt, .stream]
        let ext = SRTHandshakeExtension(
            srtVersion: 0x0001_0500,
            srtFlags: flags,
            receiverTSBPDDelay: 0,
            senderTSBPDDelay: 0
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        ext.encode(into: &buffer)
        let decoded = try SRTHandshakeExtension.decode(from: &buffer)
        #expect(decoded.srtFlags.contains(.tsbpdSender))
        #expect(decoded.srtFlags.contains(.crypt))
        #expect(decoded.srtFlags.contains(.stream))
        #expect(!decoded.srtFlags.contains(.tlpktDrop))
    }

    @Test("TSBPD delay values")
    func tsbpdDelayValues() throws {
        let ext = SRTHandshakeExtension(
            srtVersion: 0x0001_0500,
            srtFlags: [],
            receiverTSBPDDelay: 0xFFFF,
            senderTSBPDDelay: 0x1234
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        ext.encode(into: &buffer)
        let decoded = try SRTHandshakeExtension.decode(from: &buffer)
        #expect(decoded.receiverTSBPDDelay == 0xFFFF)
        #expect(decoded.senderTSBPDDelay == 0x1234)
    }

    @Test("SRTHandshakeExtension encoded size is 12 bytes")
    func encodedSize() {
        let ext = SRTHandshakeExtension(
            srtVersion: 1, srtFlags: [], receiverTSBPDDelay: 0, senderTSBPDDelay: 0
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        ext.encode(into: &buffer)
        #expect(buffer.readableBytes == 12)
    }

    // MARK: - StreamIDExtension

    @Test("StreamID encode/decode roundtrip")
    func streamIDRoundtrip() throws {
        let original = StreamIDExtension(streamID: "live/stream1")
        var buffer = ByteBufferAllocator().buffer(capacity: 32)
        original.encode(into: &buffer)
        let decoded = try StreamIDExtension.decode(from: &buffer, length: buffer.readableBytes)
        #expect(decoded == original)
    }

    @Test("StreamID with padding (non-4-byte-aligned)")
    func streamIDPadding() {
        let sid = StreamIDExtension(streamID: "abc")  // 3 bytes + 1 padding
        var buffer = ByteBufferAllocator().buffer(capacity: 8)
        sid.encode(into: &buffer)
        #expect(buffer.readableBytes == 4)
    }

    @Test("StreamID already 4-byte aligned")
    func streamIDAligned() {
        let sid = StreamIDExtension(streamID: "abcd")  // 4 bytes, no padding
        var buffer = ByteBufferAllocator().buffer(capacity: 8)
        sid.encode(into: &buffer)
        #expect(buffer.readableBytes == 4)
    }

    @Test("StreamID empty string")
    func streamIDEmpty() throws {
        let original = StreamIDExtension(streamID: "")
        var buffer = ByteBufferAllocator().buffer(capacity: 8)
        original.encode(into: &buffer)
        // Empty string encodes to 0 bytes
        let decoded = try StreamIDExtension.decode(from: &buffer, length: buffer.readableBytes)
        #expect(decoded.streamID == "")
    }

    @Test("StreamID max length (512 bytes)")
    func streamIDMaxLength() throws {
        let longString = String(repeating: "x", count: 512)
        let original = StreamIDExtension(streamID: longString)
        var buffer = ByteBufferAllocator().buffer(capacity: 520)
        original.encode(into: &buffer)
        let decoded = try StreamIDExtension.decode(from: &buffer, length: buffer.readableBytes)
        #expect(decoded.streamID == longString)
    }

    @Test("StreamID wire format matches SRT spec — bytes inverted per 4-byte chunk")
    func streamIDWireFormat() throws {
        // SRT spec: "STREAM" → padded "STREAM\0\0" → wire "ERTS\0\0MA"
        let ext = StreamIDExtension(streamID: "STREAM")
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        ext.encode(into: &buffer)
        let readResult = buffer.readBytes(length: buffer.readableBytes)
        let wireBytes = try #require(readResult)
        let expected: [UInt8] = [
            0x45, 0x52, 0x54, 0x53,  // "ERTS" (inverted "STRE")
            0x00, 0x00, 0x4D, 0x41  // "\0\0MA" (inverted "AM\0\0")
        ]
        #expect(wireBytes == expected)
    }

    @Test("StreamID wire format roundtrip with libsrt-compatible bytes")
    func streamIDWireFormatDecode() throws {
        // Simulate receiving "STREAM" from libsrt (wire bytes are inverted)
        var buffer = ByteBufferAllocator().buffer(capacity: 8)
        buffer.writeBytes([
            0x45, 0x52, 0x54, 0x53,  // "ERTS"
            0x00, 0x00, 0x4D, 0x41  // "\0\0MA"
        ])
        let decoded = try StreamIDExtension.decode(from: &buffer, length: 8)
        #expect(decoded.streamID == "STREAM")
    }

    @Test("StreamID access control wire format")
    func streamIDAccessControlWireFormat() throws {
        let sid = "#!::r=live/feed1,m=publish"
        let ext = StreamIDExtension(streamID: sid)
        var buffer = ByteBufferAllocator().buffer(capacity: 32)
        ext.encode(into: &buffer)
        let len = buffer.readableBytes
        let decoded = try StreamIDExtension.decode(from: &buffer, length: len)
        #expect(decoded.streamID == sid)
        // Verify wire bytes are NOT the same as raw UTF-8 (they are inverted)
        buffer.clear()
        ext.encode(into: &buffer)
        let readWire = buffer.readBytes(length: buffer.readableBytes)
        let wire = try #require(readWire)
        let raw = Array(sid.utf8)
        // First 4 bytes must differ (unless the string happens to be a palindrome)
        #expect(wire[0] != raw[0])
    }

    // MARK: - HandshakeExtensionHeader

    @Test("Extension header encode/decode")
    func headerRoundtrip() throws {
        let header = HandshakeExtensionHeader(extensionType: 0x0001, extensionLength: 3)
        var buffer = ByteBufferAllocator().buffer(capacity: 8)
        header.encode(into: &buffer)
        let decoded = try HandshakeExtensionHeader.decode(from: &buffer)
        #expect(decoded == header)
    }

    @Test("Extension length in 4-byte words")
    func headerLengthInWords() {
        let header = HandshakeExtensionHeader(extensionType: 0x0001, extensionLength: 3)
        #expect(header.contentLengthBytes == 12)
    }

    @Test("Header encoded size is 4 bytes")
    func headerEncodedSize() {
        let header = HandshakeExtensionHeader(extensionType: 1, extensionLength: 1)
        var buffer = ByteBufferAllocator().buffer(capacity: 8)
        header.encode(into: &buffer)
        #expect(buffer.readableBytes == 4)
    }

    @Test("Header buffer too small throws error")
    func headerBufferTooSmall() {
        var buffer = ByteBufferAllocator().buffer(capacity: 2)
        buffer.writeInteger(UInt16(0))
        #expect(throws: SRTError.self) {
            try HandshakeExtensionHeader.decode(from: &buffer)
        }
    }

    // MARK: - HandshakeExtensionType

    @Test("All 8 extension types exist")
    func extensionTypeCaseCount() {
        #expect(HandshakeExtensionType.allCases.count == 8)
    }

    @Test("Extension type raw values")
    func extensionTypeRawValues() {
        #expect(HandshakeExtensionType.srtHandshakeRequest.rawValue == 0x0001)
        #expect(HandshakeExtensionType.srtHandshakeResponse.rawValue == 0x0002)
        #expect(HandshakeExtensionType.kmRequest.rawValue == 0x0003)
        #expect(HandshakeExtensionType.kmResponse.rawValue == 0x0004)
        #expect(HandshakeExtensionType.streamID.rawValue == 0x0005)
        #expect(HandshakeExtensionType.congestion.rawValue == 0x0006)
        #expect(HandshakeExtensionType.filter.rawValue == 0x0007)
        #expect(HandshakeExtensionType.group.rawValue == 0x0008)
    }

    @Test("Extension type descriptions are non-empty")
    func extensionTypeDescriptions() {
        for ext in HandshakeExtensionType.allCases {
            #expect(!ext.description.isEmpty)
        }
    }
}
