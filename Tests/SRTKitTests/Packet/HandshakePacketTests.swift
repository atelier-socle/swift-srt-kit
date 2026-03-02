// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("HandshakePacket Tests")
struct HandshakePacketTests {
    // MARK: - Roundtrip per HandshakeType

    @Test("Roundtrip for each HandshakeType", arguments: HandshakePacket.HandshakeType.allCases)
    func roundtripAllTypes(hsType: HandshakePacket.HandshakeType) throws {
        let original = HandshakePacket(
            version: 5,
            handshakeType: hsType,
            srtSocketID: 0x1234
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        original.encode(into: &buffer)
        let decoded = try HandshakePacket.decode(from: &buffer)
        #expect(decoded == original)
    }

    // MARK: - Version

    @Test("Version 4 roundtrip")
    func version4() throws {
        let hs = HandshakePacket(version: 4, handshakeType: .induction, srtSocketID: 1)
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        hs.encode(into: &buffer)
        let decoded = try HandshakePacket.decode(from: &buffer)
        #expect(decoded.version == 4)
    }

    @Test("Version 5 roundtrip")
    func version5() throws {
        let hs = HandshakePacket(version: 5, handshakeType: .conclusion, srtSocketID: 1)
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        hs.encode(into: &buffer)
        let decoded = try HandshakePacket.decode(from: &buffer)
        #expect(decoded.version == 5)
    }

    // MARK: - Encryption field

    @Test("Encryption field 0 (none)", arguments: [UInt16(0), UInt16(2), UInt16(3), UInt16(4)] as [UInt16])
    func encryptionFieldValues(enc: UInt16) throws {
        let hs = HandshakePacket(version: 5, encryptionField: enc, handshakeType: .induction, srtSocketID: 1)
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        hs.encode(into: &buffer)
        let decoded = try HandshakePacket.decode(from: &buffer)
        #expect(decoded.encryptionField == enc)
    }

    // MARK: - Extension flags

    @Test("Extension field as bitmask")
    func extensionFieldBitmask() throws {
        let flags: HandshakePacket.ExtensionFlags = [.hsreq, .kmreq, .config]
        let hs = HandshakePacket(
            version: 5,
            extensionField: flags.rawValue,
            handshakeType: .conclusion,
            srtSocketID: 1
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        hs.encode(into: &buffer)
        let decoded = try HandshakePacket.decode(from: &buffer)
        let decodedFlags = HandshakePacket.ExtensionFlags(rawValue: decoded.extensionField)
        #expect(decodedFlags.contains(.hsreq))
        #expect(decodedFlags.contains(.kmreq))
        #expect(decodedFlags.contains(.config))
    }

    @Test("Extension flags individual values")
    func extensionFlagsIndividual() {
        #expect(HandshakePacket.ExtensionFlags.hsreq.rawValue == 0x0001)
        #expect(HandshakePacket.ExtensionFlags.kmreq.rawValue == 0x0002)
        #expect(HandshakePacket.ExtensionFlags.config.rawValue == 0x0004)
    }

    // MARK: - Peer address

    @Test("IPv4 peer address roundtrip")
    func ipv4PeerAddress() throws {
        let hs = HandshakePacket(
            version: 5,
            handshakeType: .induction,
            srtSocketID: 1,
            peerIPAddress: .ipv4(0xC0A8_0001)
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        hs.encode(into: &buffer)
        let decoded = try HandshakePacket.decode(from: &buffer)
        #expect(decoded.peerIPAddress == .ipv4(0xC0A8_0001))
    }

    @Test("IPv6 peer address roundtrip")
    func ipv6PeerAddress() throws {
        let hs = HandshakePacket(
            version: 5,
            handshakeType: .induction,
            srtSocketID: 1,
            peerIPAddress: .ipv6(0xFE80_0000_0000_0000, 0x0000_0000_0000_0001)
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        hs.encode(into: &buffer)
        let decoded = try HandshakePacket.decode(from: &buffer)
        #expect(decoded.peerIPAddress == .ipv6(0xFE80_0000_0000_0000, 0x0000_0000_0000_0001))
    }

    // MARK: - Field preservation

    @Test("Initial packet sequence number preservation")
    func initialSeqPreservation() throws {
        let hs = HandshakePacket(
            version: 5,
            initialPacketSequenceNumber: SequenceNumber(0x1234_5678),
            handshakeType: .induction,
            srtSocketID: 1
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        hs.encode(into: &buffer)
        let decoded = try HandshakePacket.decode(from: &buffer)
        #expect(decoded.initialPacketSequenceNumber == SequenceNumber(0x1234_5678))
    }

    @Test("MTU and flow window size preservation")
    func mtuAndFlowWindow() throws {
        let hs = HandshakePacket(
            version: 5,
            maxTransmissionUnitSize: 1500,
            maxFlowWindowSize: 8192,
            handshakeType: .induction,
            srtSocketID: 1
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        hs.encode(into: &buffer)
        let decoded = try HandshakePacket.decode(from: &buffer)
        #expect(decoded.maxTransmissionUnitSize == 1500)
        #expect(decoded.maxFlowWindowSize == 8192)
    }

    @Test("SYN cookie preservation")
    func synCookiePreservation() throws {
        let hs = HandshakePacket(
            version: 5,
            handshakeType: .induction,
            srtSocketID: 1,
            synCookie: 0xDEAD_BEEF
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        hs.encode(into: &buffer)
        let decoded = try HandshakePacket.decode(from: &buffer)
        #expect(decoded.synCookie == 0xDEAD_BEEF)
    }

    @Test("SRT Socket ID preservation")
    func socketIDPreservation() throws {
        let hs = HandshakePacket(
            version: 5,
            handshakeType: .conclusion,
            srtSocketID: 0xABCD_EF01
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        hs.encode(into: &buffer)
        let decoded = try HandshakePacket.decode(from: &buffer)
        #expect(decoded.srtSocketID == 0xABCD_EF01)
    }

    // MARK: - Full preservation

    @Test("All fields preserved in roundtrip")
    func allFieldsPreserved() throws {
        let original = HandshakePacket(
            version: 5,
            encryptionField: 4,
            extensionField: 0x0007,
            initialPacketSequenceNumber: SequenceNumber(0x7FFF_FFFF),
            maxTransmissionUnitSize: 1500,
            maxFlowWindowSize: 25600,
            handshakeType: .conclusion,
            srtSocketID: 0xFFFF_FFFF,
            synCookie: 0x1234_5678,
            peerIPAddress: .ipv4(0xAC10_FE01)
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        original.encode(into: &buffer)
        let decoded = try HandshakePacket.decode(from: &buffer)
        #expect(decoded == original)
    }

    // MARK: - CIF size

    @Test("Encoded CIF is exactly 48 bytes")
    func encodedCIFSize() {
        let hs = HandshakePacket(version: 5, handshakeType: .induction, srtSocketID: 1)
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        hs.encode(into: &buffer)
        #expect(buffer.readableBytes == 48)
    }

    // MARK: - Error handling

    @Test("Buffer too small throws error")
    func bufferTooSmall() {
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        buffer.writeInteger(UInt64(0))
        buffer.writeInteger(UInt64(0))
        #expect(throws: SRTError.self) {
            try HandshakePacket.decode(from: &buffer)
        }
    }

    // MARK: - HandshakeType

    @Test("HandshakeType descriptions")
    func handshakeTypeDescriptions() {
        #expect(HandshakePacket.HandshakeType.done.description == "done")
        #expect(HandshakePacket.HandshakeType.agreement.description == "agreement")
        #expect(HandshakePacket.HandshakeType.conclusion.description == "conclusion")
        #expect(HandshakePacket.HandshakeType.waveahand.description == "waveahand")
        #expect(HandshakePacket.HandshakeType.induction.description == "induction")
    }

    @Test("All 5 HandshakeType cases exist")
    func handshakeTypeCaseCount() {
        #expect(HandshakePacket.HandshakeType.allCases.count == 5)
    }
}
