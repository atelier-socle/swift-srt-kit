// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("ControlInfoField Tests")
struct ControlInfoFieldTests {
    @Test("decodeCIF dispatches handshake correctly")
    func decodeCIFHandshake() throws {
        let hs = HandshakePacket(version: 5, handshakeType: .induction, srtSocketID: 1)
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        hs.encode(into: &buffer)
        let cif = try PacketCodec.decodeCIF(
            controlType: .handshake, from: &buffer, cifLength: buffer.readableBytes
        )
        if case .handshake(let decoded) = cif {
            #expect(decoded.handshakeType == .induction)
        } else {
            #expect(Bool(false), "Expected handshake CIF")
        }
    }

    @Test("decodeCIF dispatches ACK correctly")
    func decodeCIFAck() throws {
        let ack = ACKPacket(acknowledgementNumber: SequenceNumber(100))
        var buffer = ByteBufferAllocator().buffer(capacity: 8)
        ack.encode(into: &buffer)
        let cif = try PacketCodec.decodeCIF(
            controlType: .ack, from: &buffer, cifLength: buffer.readableBytes
        )
        if case .ack(let decoded) = cif {
            #expect(decoded.acknowledgementNumber.value == 100)
        } else {
            #expect(Bool(false), "Expected ACK CIF")
        }
    }

    @Test("decodeCIF dispatches NAK correctly")
    func decodeCIFNak() throws {
        let nak = NAKPacket(lossEntries: [.single(SequenceNumber(42))])
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        nak.encode(into: &buffer)
        let cif = try PacketCodec.decodeCIF(
            controlType: .nak, from: &buffer, cifLength: buffer.readableBytes
        )
        if case .nak(let decoded) = cif {
            #expect(decoded.lossEntries.count == 1)
        } else {
            #expect(Bool(false), "Expected NAK CIF")
        }
    }

    @Test("decodeCIF keepalive returns .keepalive")
    func decodeCIFKeepalive() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        let cif = try PacketCodec.decodeCIF(
            controlType: .keepalive, from: &buffer, cifLength: 0
        )
        #expect(cif == .keepalive)
    }

    @Test("decodeCIF shutdown returns .shutdown")
    func decodeCIFShutdown() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        let cif = try PacketCodec.decodeCIF(
            controlType: .shutdown, from: &buffer, cifLength: 0
        )
        #expect(cif == .shutdown)
    }

    @Test("decodeCIF ackack returns .ackack")
    func decodeCIFAckAck() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        let cif = try PacketCodec.decodeCIF(
            controlType: .ackack, from: &buffer, cifLength: 0
        )
        #expect(cif == .ackack)
    }

    @Test("decodeCIF userDefined returns raw bytes")
    func decodeCIFUserDefined() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 8)
        buffer.writeBytes([0x01, 0x02, 0x03, 0x04])
        let cif = try PacketCodec.decodeCIF(
            controlType: .userDefined, from: &buffer, cifLength: 4
        )
        if case .raw(let bytes) = cif {
            #expect(bytes == [0x01, 0x02, 0x03, 0x04])
        } else {
            #expect(Bool(false), "Expected raw CIF")
        }
    }

    @Test("Handshake CIF through full encode/decode pipeline")
    func handshakePipeline() throws {
        let hs = HandshakePacket(
            version: 5,
            encryptionField: 2,
            handshakeType: .conclusion,
            srtSocketID: 0xABCD,
            synCookie: 0x1234,
            peerIPAddress: .ipv4(0x7F00_0001)
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 128)
        PacketCodec.encode(
            controlType: .handshake,
            timestamp: 5000,
            destinationSocketID: 0xFF,
            cif: .handshake(hs),
            into: &buffer
        )
        let packet = try PacketCodec.decode(from: &buffer)
        guard case .control(let ctrl) = packet else {
            #expect(Bool(false), "Expected control packet")
            return
        }
        #expect(ctrl.controlType == .handshake)
        var cifBuffer = ByteBufferAllocator().buffer(capacity: ctrl.controlInfoField.count)
        cifBuffer.writeBytes(ctrl.controlInfoField)
        let cif = try PacketCodec.decodeCIF(
            controlType: .handshake, from: &cifBuffer, cifLength: cifBuffer.readableBytes
        )
        if case .handshake(let decoded) = cif {
            #expect(decoded == hs)
        } else {
            #expect(Bool(false), "Expected handshake CIF")
        }
    }

    @Test("peerError CIF roundtrip")
    func peerErrorCIF() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 4)
        buffer.writeInteger(UInt32(42))
        let cif = try PacketCodec.decodeCIF(
            controlType: .peererror, from: &buffer, cifLength: 4
        )
        #expect(cif == .peerError(42))
    }

    @Test("dropRequest CIF through decodeCIF")
    func dropRequestCIF() throws {
        let drop = DropRequestPacket(
            messageNumber: 99,
            firstSequence: SequenceNumber(10),
            lastSequence: SequenceNumber(20)
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        drop.encode(into: &buffer)
        let cif = try PacketCodec.decodeCIF(
            controlType: .dropreq, from: &buffer, cifLength: buffer.readableBytes, typeSpecificInfo: 99
        )
        if case .dropRequest(let decoded) = cif {
            #expect(decoded == drop)
        } else {
            #expect(Bool(false), "Expected dropRequest CIF")
        }
    }
}
