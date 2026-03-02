// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("DropRequestPacket Tests")
struct DropRequestPacketTests {
    @Test("Encode/decode roundtrip")
    func roundtrip() throws {
        let original = DropRequestPacket(
            messageNumber: 42,
            firstSequence: SequenceNumber(100),
            lastSequence: SequenceNumber(110)
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        original.encode(into: &buffer)
        let decoded = try DropRequestPacket.decode(from: &buffer, messageNumber: 42)
        #expect(decoded == original)
    }

    @Test("Message number preservation")
    func messageNumberPreservation() throws {
        let original = DropRequestPacket(
            messageNumber: 0xDEAD_BEEF,
            firstSequence: SequenceNumber(1),
            lastSequence: SequenceNumber(10)
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        original.encode(into: &buffer)
        let decoded = try DropRequestPacket.decode(from: &buffer, messageNumber: 0xDEAD_BEEF)
        #expect(decoded.messageNumber == 0xDEAD_BEEF)
    }

    @Test("First/last sequence preservation")
    func sequencePreservation() throws {
        let original = DropRequestPacket(
            messageNumber: 1,
            firstSequence: SequenceNumber(0x7FFF_FFFE),
            lastSequence: SequenceNumber(0x7FFF_FFFF)
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        original.encode(into: &buffer)
        let decoded = try DropRequestPacket.decode(from: &buffer, messageNumber: 1)
        #expect(decoded.firstSequence == SequenceNumber(0x7FFF_FFFE))
        #expect(decoded.lastSequence == SequenceNumber(0x7FFF_FFFF))
    }

    @Test("Single packet drop (first == last)")
    func singlePacketDrop() throws {
        let original = DropRequestPacket(
            messageNumber: 5,
            firstSequence: SequenceNumber(42),
            lastSequence: SequenceNumber(42)
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        original.encode(into: &buffer)
        let decoded = try DropRequestPacket.decode(from: &buffer, messageNumber: 5)
        #expect(decoded.firstSequence == decoded.lastSequence)
    }

    @Test("Encoded CIF is 8 bytes")
    func encodedSize() {
        let drop = DropRequestPacket(
            messageNumber: 1,
            firstSequence: SequenceNumber(1),
            lastSequence: SequenceNumber(2)
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        drop.encode(into: &buffer)
        #expect(buffer.readableBytes == 8)
    }

    @Test("Buffer too small throws error")
    func bufferTooSmall() {
        var buffer = ByteBufferAllocator().buffer(capacity: 4)
        buffer.writeInteger(UInt32(0))
        #expect(throws: SRTError.self) {
            try DropRequestPacket.decode(from: &buffer, messageNumber: 0)
        }
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = DropRequestPacket(messageNumber: 1, firstSequence: SequenceNumber(1), lastSequence: SequenceNumber(2))
        let b = DropRequestPacket(messageNumber: 1, firstSequence: SequenceNumber(1), lastSequence: SequenceNumber(2))
        let c = DropRequestPacket(messageNumber: 2, firstSequence: SequenceNumber(1), lastSequence: SequenceNumber(2))
        #expect(a == b)
        #expect(a != c)
    }
}
