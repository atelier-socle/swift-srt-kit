// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("PacketCodec Tests")
struct PacketCodecTests {
    // MARK: - F bit dispatch

    @Test("F=0 decodes as data packet")
    func fBitZeroIsData() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        // Word 0: F=0, seq=1
        buffer.writeInteger(UInt32(0x0000_0001))
        // Word 1: PP=11 (single), O=0, KK=00, R=0, msgno=0
        buffer.writeInteger(UInt32(0xC000_0000))
        // Word 2: timestamp
        buffer.writeInteger(UInt32(0))
        // Word 3: dest socket ID
        buffer.writeInteger(UInt32(0))

        let packet = try PacketCodec.decode(from: &buffer)
        guard case .data = packet else {
            #expect(Bool(false), "Expected data packet")
            return
        }
        #expect(true)
    }

    @Test("F=1 decodes as control packet")
    func fBitOneIsControl() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        // Word 0: F=1, control type=0x0001 (keepalive), subtype=0
        buffer.writeInteger(UInt32(0x8001_0000))
        // Word 1: type-specific info
        buffer.writeInteger(UInt32(0))
        // Word 2: timestamp
        buffer.writeInteger(UInt32(0))
        // Word 3: dest socket ID
        buffer.writeInteger(UInt32(0))

        let packet = try PacketCodec.decode(from: &buffer)
        guard case .control(let ctrl) = packet else {
            #expect(Bool(false), "Expected control packet")
            return
        }
        #expect(ctrl.controlType == .keepalive)
    }

    // MARK: - Error handling

    @Test("Buffer too small throws invalidPacket")
    func bufferTooSmall() {
        var buffer = ByteBufferAllocator().buffer(capacity: 4)
        buffer.writeInteger(UInt32(0))
        #expect(throws: SRTError.self) {
            try PacketCodec.decode(from: &buffer)
        }
    }

    @Test("Empty buffer throws invalidPacket")
    func emptyBuffer() {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        #expect(throws: SRTError.self) {
            try PacketCodec.decode(from: &buffer)
        }
    }

    @Test("Unknown control type throws invalidPacket")
    func unknownControlType() {
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        // F=1, control type=0x0100 (not in ControlType enum), subtype=0
        buffer.writeInteger(UInt32(0x8100_0000))
        buffer.writeInteger(UInt32(0))
        buffer.writeInteger(UInt32(0))
        buffer.writeInteger(UInt32(0))
        #expect(throws: SRTError.self) {
            try PacketCodec.decode(from: &buffer)
        }
    }

    // MARK: - Full roundtrip

    @Test("Full data packet roundtrip with known bytes")
    func dataPacketKnownBytes() throws {
        let original = SRTDataPacket(
            sequenceNumber: SequenceNumber(0x1234),
            position: .single,
            orderFlag: false,
            encryptionKey: .none,
            retransmitted: false,
            messageNumber: 0x56,
            timestamp: 0xAABB_CCDD,
            destinationSocketID: 0x1122_3344,
            payload: [0xFF, 0xFE, 0xFD]
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.data(original), into: &buffer)

        // Verify F bit is 0
        let firstByte = buffer.getInteger(at: buffer.readerIndex, as: UInt8.self)
        #expect(firstByte != nil)
        if let byte = firstByte {
            #expect((byte & 0x80) == 0, "F bit should be 0 for data packet")
        }

        let decoded = try PacketCodec.decode(from: &buffer)
        guard case .data(let result) = decoded else {
            #expect(Bool(false), "Expected data packet")
            return
        }
        #expect(result == original)
    }

    @Test("Full control packet roundtrip with known bytes")
    func controlPacketKnownBytes() throws {
        let original = SRTControlPacket(
            controlType: .ack,
            subtype: 0,
            typeSpecificInfo: 0x42,
            timestamp: 0x1000,
            destinationSocketID: 0xABCD
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.control(original), into: &buffer)

        // Verify F bit is 1
        let firstByte = buffer.getInteger(at: buffer.readerIndex, as: UInt8.self)
        #expect(firstByte != nil)
        if let byte = firstByte {
            #expect((byte & 0x80) != 0, "F bit should be 1 for control packet")
        }

        let decoded = try PacketCodec.decode(from: &buffer)
        guard case .control(let result) = decoded else {
            #expect(Bool(false), "Expected control packet")
            return
        }
        #expect(result == original)
    }

    @Test("Byte order is big-endian (network byte order)")
    func byteOrderVerification() {
        let packet = SRTDataPacket(
            sequenceNumber: SequenceNumber(0x0102_0304),
            position: .single,
            messageNumber: 0,
            timestamp: 0x0A0B_0C0D,
            destinationSocketID: 0x1A1B_1C1D
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.data(packet), into: &buffer)

        // Word 0: sequence number 0x01020304 with F=0
        let byte0 = buffer.getInteger(at: 0, as: UInt8.self)
        let byte1 = buffer.getInteger(at: 1, as: UInt8.self)
        let byte2 = buffer.getInteger(at: 2, as: UInt8.self)
        let byte3 = buffer.getInteger(at: 3, as: UInt8.self)
        #expect(byte0 == 0x01)
        #expect(byte1 == 0x02)
        #expect(byte2 == 0x03)
        #expect(byte3 == 0x04)

        // Word 2 (offset 8): timestamp 0x0A0B0C0D
        let ts0 = buffer.getInteger(at: 8, as: UInt8.self)
        let ts1 = buffer.getInteger(at: 9, as: UInt8.self)
        let ts2 = buffer.getInteger(at: 10, as: UInt8.self)
        let ts3 = buffer.getInteger(at: 11, as: UInt8.self)
        #expect(ts0 == 0x0A)
        #expect(ts1 == 0x0B)
        #expect(ts2 == 0x0C)
        #expect(ts3 == 0x0D)
    }

    @Test("Minimum header size constant is 16")
    func minimumHeaderSizeIs16() {
        #expect(PacketCodec.minimumHeaderSize == 16)
    }

    @Test("Encode and decode multiple packets sequentially")
    func multiplePacketsSequential() throws {
        let data1 = SRTDataPacket(sequenceNumber: SequenceNumber(1), payload: [0x01])
        let ctrl1 = SRTControlPacket(controlType: .keepalive)
        let data2 = SRTDataPacket(sequenceNumber: SequenceNumber(2), payload: [0x02])

        var buf1 = ByteBufferAllocator().buffer(capacity: 64)
        var buf2 = ByteBufferAllocator().buffer(capacity: 64)
        var buf3 = ByteBufferAllocator().buffer(capacity: 64)

        PacketCodec.encode(.data(data1), into: &buf1)
        PacketCodec.encode(.control(ctrl1), into: &buf2)
        PacketCodec.encode(.data(data2), into: &buf3)

        let decoded1 = try PacketCodec.decode(from: &buf1)
        let decoded2 = try PacketCodec.decode(from: &buf2)
        let decoded3 = try PacketCodec.decode(from: &buf3)

        guard case .data(let r1) = decoded1 else {
            #expect(Bool(false), "Expected data packet 1")
            return
        }
        guard case .control(let r2) = decoded2 else {
            #expect(Bool(false), "Expected control packet")
            return
        }
        guard case .data(let r3) = decoded3 else {
            #expect(Bool(false), "Expected data packet 2")
            return
        }

        #expect(r1.sequenceNumber.value == 1)
        #expect(r2.controlType == .keepalive)
        #expect(r3.sequenceNumber.value == 2)
    }
}
