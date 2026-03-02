// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("ACKPacket Tests")
struct ACKPacketTests {
    @Test("Full ACK encode/decode roundtrip")
    func fullACKRoundtrip() throws {
        let original = ACKPacket(
            acknowledgementNumber: SequenceNumber(1000),
            rtt: 25000,
            rttVariance: 5000,
            availableBufferSize: 100,
            packetsReceivingRate: 50000,
            estimatedLinkCapacity: 100_000,
            receivingRate: 1_000_000
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 32)
        original.encode(into: &buffer)
        let decoded = try ACKPacket.decode(from: &buffer, cifLength: buffer.readableBytes)
        #expect(decoded == original)
    }

    @Test("Light ACK encode/decode roundtrip")
    func lightACKRoundtrip() throws {
        let original = ACKPacket(acknowledgementNumber: SequenceNumber(500))
        var buffer = ByteBufferAllocator().buffer(capacity: 8)
        original.encode(into: &buffer)
        let decoded = try ACKPacket.decode(from: &buffer, cifLength: buffer.readableBytes)
        #expect(decoded == original)
        #expect(decoded.isLightACK)
    }

    @Test("Light ACK has nil optional fields")
    func lightACKNilFields() {
        let ack = ACKPacket(acknowledgementNumber: SequenceNumber(1))
        #expect(ack.rtt == nil)
        #expect(ack.rttVariance == nil)
        #expect(ack.availableBufferSize == nil)
        #expect(ack.packetsReceivingRate == nil)
        #expect(ack.estimatedLinkCapacity == nil)
        #expect(ack.receivingRate == nil)
        #expect(ack.isLightACK)
    }

    @Test("Full ACK is not light ACK")
    func fullACKNotLight() {
        let ack = ACKPacket(
            acknowledgementNumber: SequenceNumber(1),
            rtt: 1000,
            rttVariance: 100,
            availableBufferSize: 50,
            packetsReceivingRate: 1000,
            estimatedLinkCapacity: 2000,
            receivingRate: 500_000
        )
        #expect(!ack.isLightACK)
    }

    @Test("Full ACK max field values")
    func fullACKMaxValues() throws {
        let original = ACKPacket(
            acknowledgementNumber: SequenceNumber(0x7FFF_FFFF),
            rtt: 0xFFFF_FFFF,
            rttVariance: 0xFFFF_FFFF,
            availableBufferSize: 0xFFFF_FFFF,
            packetsReceivingRate: 0xFFFF_FFFF,
            estimatedLinkCapacity: 0xFFFF_FFFF,
            receivingRate: 0xFFFF_FFFF
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 32)
        original.encode(into: &buffer)
        let decoded = try ACKPacket.decode(from: &buffer, cifLength: buffer.readableBytes)
        #expect(decoded == original)
    }

    @Test("Acknowledgement number preservation")
    func ackNumberPreservation() throws {
        let original = ACKPacket(acknowledgementNumber: SequenceNumber(0x1234_5678))
        var buffer = ByteBufferAllocator().buffer(capacity: 8)
        original.encode(into: &buffer)
        let decoded = try ACKPacket.decode(from: &buffer, cifLength: buffer.readableBytes)
        #expect(decoded.acknowledgementNumber == SequenceNumber(0x1234_5678))
    }

    @Test("CIF length 4 produces light ACK")
    func cifLength4IsLight() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 4)
        buffer.writeInteger(UInt32(42))
        let decoded = try ACKPacket.decode(from: &buffer, cifLength: 4)
        #expect(decoded.isLightACK)
        #expect(decoded.acknowledgementNumber.value == 42)
    }

    @Test("CIF length 28 produces full ACK")
    func cifLength28IsFull() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 28)
        buffer.writeInteger(UInt32(42))  // ack number
        buffer.writeInteger(UInt32(100))  // rtt
        buffer.writeInteger(UInt32(10))  // rtt variance
        buffer.writeInteger(UInt32(50))  // buffer size
        buffer.writeInteger(UInt32(1000))  // packets rate
        buffer.writeInteger(UInt32(2000))  // link capacity
        buffer.writeInteger(UInt32(3000))  // receiving rate
        let decoded = try ACKPacket.decode(from: &buffer, cifLength: 28)
        #expect(!decoded.isLightACK)
        #expect(decoded.rtt == 100)
    }

    @Test("CIF length too small throws error")
    func cifTooSmall() {
        var buffer = ByteBufferAllocator().buffer(capacity: 2)
        buffer.writeInteger(UInt16(0))
        #expect(throws: SRTError.self) {
            try ACKPacket.decode(from: &buffer, cifLength: 2)
        }
    }

    @Test("Light ACK encoded size is 4 bytes")
    func lightACKEncodedSize() {
        let ack = ACKPacket(acknowledgementNumber: SequenceNumber(1))
        var buffer = ByteBufferAllocator().buffer(capacity: 8)
        ack.encode(into: &buffer)
        #expect(buffer.readableBytes == 4)
    }

    @Test("Full ACK encoded size is 28 bytes")
    func fullACKEncodedSize() {
        let ack = ACKPacket(
            acknowledgementNumber: SequenceNumber(1),
            rtt: 1, rttVariance: 1, availableBufferSize: 1,
            packetsReceivingRate: 1, estimatedLinkCapacity: 1, receivingRate: 1
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 32)
        ack.encode(into: &buffer)
        #expect(buffer.readableBytes == 28)
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = ACKPacket(acknowledgementNumber: SequenceNumber(1))
        let b = ACKPacket(acknowledgementNumber: SequenceNumber(1))
        let c = ACKPacket(acknowledgementNumber: SequenceNumber(2))
        #expect(a == b)
        #expect(a != c)
    }
}
