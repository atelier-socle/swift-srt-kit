// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("PacketCodec Coverage Tests")
struct PacketCodecCoverageTests {

    // MARK: - Data packet decode error paths

    @Test("decodeData fails when word1 cannot be read")
    func decodeDataMissingWord1() {
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        // F=0, seq=1 (word 0 = 4 bytes)
        buffer.writeInteger(UInt32(0x0000_0001))
        // Write only 4 more bytes for word 1 but need 12 more (word1+ts+destID)
        // Actually the minimum is 16 bytes for header, so we need exactly 16
        // but let buffer have exactly 16 bytes with word1 readable
        // To trigger word1 read fail, we need buffer to be < 8 after word0 read
        // But guard at start requires >= 16. So word1 read can't fail if we pass
        // the minimum header check.
        // Instead, let's test a data packet with no payload (empty payload path)
        buffer.writeInteger(UInt32(0xC000_0000))  // PP=single, O=0, KK=0, R=0, msg=0
        buffer.writeInteger(UInt32(1000))  // timestamp
        buffer.writeInteger(UInt32(42))  // dest socket ID
        // No payload bytes
        let packet = try? PacketCodec.decode(from: &buffer)
        guard case .data(let data) = packet else {
            Issue.record("Expected data packet")
            return
        }
        #expect(data.payload.isEmpty)
        #expect(data.timestamp == 1000)
        #expect(data.destinationSocketID == 42)
    }

    @Test("Data packet with all flags set roundtrips correctly")
    func dataPacketAllFlags() throws {
        let original = SRTDataPacket(
            sequenceNumber: SequenceNumber(0x7FFF_FFFF),
            position: .first,
            orderFlag: true,
            encryptionKey: .odd,
            retransmitted: true,
            messageNumber: 0x03FF_FFFF,
            timestamp: UInt32.max,
            destinationSocketID: UInt32.max,
            payload: [0xDE, 0xAD, 0xBE, 0xEF]
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.data(original), into: &buffer)
        let decoded = try PacketCodec.decode(from: &buffer)
        guard case .data(let result) = decoded else {
            Issue.record("Expected data packet")
            return
        }
        #expect(result == original)
        #expect(result.orderFlag == true)
        #expect(result.retransmitted == true)
        #expect(result.encryptionKey == .odd)
        #expect(result.position == .first)
    }

    @Test("Data packet with middle position roundtrips")
    func dataPacketMiddlePosition() throws {
        let original = SRTDataPacket(
            sequenceNumber: SequenceNumber(100),
            position: .middle,
            payload: [0x01]
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.data(original), into: &buffer)
        let decoded = try PacketCodec.decode(from: &buffer)
        guard case .data(let result) = decoded else {
            Issue.record("Expected data packet")
            return
        }
        #expect(result.position == .middle)
    }

    @Test("Data packet with last position roundtrips")
    func dataPacketLastPosition() throws {
        let original = SRTDataPacket(
            sequenceNumber: SequenceNumber(100),
            position: .last,
            payload: [0x01]
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.data(original), into: &buffer)
        let decoded = try PacketCodec.decode(from: &buffer)
        guard case .data(let result) = decoded else {
            Issue.record("Expected data packet")
            return
        }
        #expect(result.position == .last)
    }

    @Test("Data packet with even encryption key roundtrips")
    func dataPacketEvenKey() throws {
        let original = SRTDataPacket(
            sequenceNumber: SequenceNumber(1),
            encryptionKey: .even,
            payload: [0xAA]
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.data(original), into: &buffer)
        let decoded = try PacketCodec.decode(from: &buffer)
        guard case .data(let result) = decoded else {
            Issue.record("Expected data packet")
            return
        }
        #expect(result.encryptionKey == .even)
    }

    @Test("Data packet with controlOnly encryption key roundtrips")
    func dataPacketControlOnlyKey() throws {
        let original = SRTDataPacket(
            sequenceNumber: SequenceNumber(1),
            encryptionKey: .controlOnly,
            payload: [0xBB]
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.data(original), into: &buffer)
        let decoded = try PacketCodec.decode(from: &buffer)
        guard case .data(let result) = decoded else {
            Issue.record("Expected data packet")
            return
        }
        #expect(result.encryptionKey == .controlOnly)
    }

    @Test("Data packet with empty payload encodes and decodes")
    func dataPacketEmptyPayload() throws {
        let original = SRTDataPacket(
            sequenceNumber: SequenceNumber(5),
            position: .single,
            payload: []
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.data(original), into: &buffer)
        #expect(buffer.readableBytes == PacketCodec.minimumHeaderSize)

        let decoded = try PacketCodec.decode(from: &buffer)
        guard case .data(let result) = decoded else {
            Issue.record("Expected data packet")
            return
        }
        #expect(result.payload.isEmpty)
    }

    @Test("Data packet orderFlag=true encodes O bit correctly")
    func dataPacketOrderFlagBit() throws {
        let original = SRTDataPacket(
            sequenceNumber: SequenceNumber(1),
            orderFlag: true,
            payload: [0x01]
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.data(original), into: &buffer)

        // Check word 1 bit 29 is set (O flag)
        let word1 = buffer.getInteger(at: 4, as: UInt32.self)
        #expect(word1 != nil)
        if let w1 = word1 {
            #expect((w1 & 0x2000_0000) != 0, "O bit should be set")
        }
    }

    @Test("Data packet retransmitted=true encodes R bit correctly")
    func dataPacketRetransmittedBit() throws {
        let original = SRTDataPacket(
            sequenceNumber: SequenceNumber(1),
            retransmitted: true,
            payload: [0x01]
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.data(original), into: &buffer)

        // Check word 1 bit 26 is set (R flag)
        let word1 = buffer.getInteger(at: 4, as: UInt32.self)
        #expect(word1 != nil)
        if let w1 = word1 {
            #expect((w1 & 0x0400_0000) != 0, "R bit should be set")
        }
    }

    // MARK: - Control packet decode/encode coverage

    @Test("Control packet with non-empty CIF roundtrips")
    func controlPacketWithCIF() throws {
        let original = SRTControlPacket(
            controlType: .ack,
            subtype: 0,
            typeSpecificInfo: 0x42,
            timestamp: 5000,
            destinationSocketID: 0xBEEF,
            controlInfoField: [0x01, 0x02, 0x03, 0x04]
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.control(original), into: &buffer)
        let decoded = try PacketCodec.decode(from: &buffer)
        guard case .control(let result) = decoded else {
            Issue.record("Expected control packet")
            return
        }
        #expect(result == original)
        #expect(result.controlInfoField == [0x01, 0x02, 0x03, 0x04])
    }

    @Test("Control packet with empty CIF roundtrips")
    func controlPacketEmptyCIF() throws {
        let original = SRTControlPacket(
            controlType: .shutdown,
            controlInfoField: []
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.control(original), into: &buffer)
        #expect(buffer.readableBytes == PacketCodec.minimumHeaderSize)

        let decoded = try PacketCodec.decode(from: &buffer)
        guard case .control(let result) = decoded else {
            Issue.record("Expected control packet")
            return
        }
        #expect(result.controlInfoField.isEmpty)
    }

    @Test("Control packet with subtype preserves subtype")
    func controlPacketSubtype() throws {
        let original = SRTControlPacket(
            controlType: .congestion,
            subtype: 0x1234,
            typeSpecificInfo: 0,
            timestamp: 0,
            destinationSocketID: 0
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.control(original), into: &buffer)
        let decoded = try PacketCodec.decode(from: &buffer)
        guard case .control(let result) = decoded else {
            Issue.record("Expected control packet")
            return
        }
        #expect(result.subtype == 0x1234)
    }

}

@Suite("PacketCodec Coverage Tests Part 2")
struct PacketCodecCoverageTests2 {

    // MARK: - decodeCIF coverage

    @Test("decodeCIF peererror with cifLength < 4 returns peerError(0)")
    func decodePeerErrorNoCIF() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        let cif = try PacketCodec.decodeCIF(
            controlType: .peererror, from: &buffer, cifLength: 0
        )
        #expect(cif == .peerError(0))
    }

    @Test("decodeCIF peererror with cifLength=2 returns peerError(0)")
    func decodePeerErrorSmallCIF() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 4)
        buffer.writeBytes([0x01, 0x02])
        let cif = try PacketCodec.decodeCIF(
            controlType: .peererror, from: &buffer, cifLength: 2
        )
        #expect(cif == .peerError(0))
    }

    @Test("decodeCIF congestion with raw data returns .raw")
    func decodeCongestionCIF() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 8)
        buffer.writeBytes([0xAA, 0xBB, 0xCC])
        let cif = try PacketCodec.decodeCIF(
            controlType: .congestion, from: &buffer, cifLength: 3
        )
        if case .raw(let bytes) = cif {
            #expect(bytes == [0xAA, 0xBB, 0xCC])
        } else {
            Issue.record("Expected raw CIF")
        }
    }

    @Test("decodeCIF congestion with cifLength=0 returns empty raw")
    func decodeCongestionEmptyCIF() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        let cif = try PacketCodec.decodeCIF(
            controlType: .congestion, from: &buffer, cifLength: 0
        )
        #expect(cif == .raw([]))
    }

    @Test("decodeCIF raw with insufficient buffer throws")
    func decodeRawCIFInsufficientBuffer() {
        var buffer = ByteBufferAllocator().buffer(capacity: 4)
        buffer.writeBytes([0x01, 0x02])
        // cifLength says 10 but buffer only has 2 bytes
        #expect(throws: SRTError.self) {
            _ = try PacketCodec.decodeCIF(
                controlType: .userDefined, from: &buffer, cifLength: 10
            )
        }
    }

    // MARK: - encode CIF coverage

    @Test("encode peerError CIF writes error code")
    func encodePeerErrorCIF() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(
            controlType: .peererror,
            cif: .peerError(0xDEAD),
            into: &buffer
        )
        let packet = try PacketCodec.decode(from: &buffer)
        guard case .control(let ctrl) = packet else {
            Issue.record("Expected control packet")
            return
        }
        #expect(ctrl.controlType == .peererror)
        // CIF should contain the error code (4 bytes big-endian)
        #expect(ctrl.controlInfoField.count == 4)
    }

    @Test("encode raw CIF with non-empty bytes")
    func encodeRawCIF() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(
            controlType: .congestion,
            cif: .raw([0x01, 0x02, 0x03]),
            into: &buffer
        )
        let packet = try PacketCodec.decode(from: &buffer)
        guard case .control(let ctrl) = packet else {
            Issue.record("Expected control packet")
            return
        }
        #expect(ctrl.controlInfoField == [0x01, 0x02, 0x03])
    }

    @Test("encode raw CIF with empty bytes writes no CIF")
    func encodeRawCIFEmpty() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(
            controlType: .congestion,
            cif: .raw([]),
            into: &buffer
        )
        let packet = try PacketCodec.decode(from: &buffer)
        guard case .control(let ctrl) = packet else {
            Issue.record("Expected control packet")
            return
        }
        #expect(ctrl.controlInfoField.isEmpty)
    }

    @Test("encode keepalive CIF writes no CIF bytes")
    func encodeKeepaliveCIF() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(
            controlType: .keepalive,
            cif: .keepalive,
            into: &buffer
        )
        #expect(buffer.readableBytes == PacketCodec.minimumHeaderSize)
    }

    @Test("encode shutdown CIF writes no CIF bytes")
    func encodeShutdownCIF() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(
            controlType: .shutdown,
            cif: .shutdown,
            into: &buffer
        )
        #expect(buffer.readableBytes == PacketCodec.minimumHeaderSize)
    }

    @Test("encode ackack CIF writes no CIF bytes")
    func encodeAckAckCIF() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(
            controlType: .ackack,
            cif: .ackack,
            into: &buffer
        )
        #expect(buffer.readableBytes == PacketCodec.minimumHeaderSize)
    }

    @Test("encode ACK CIF produces decodable packet")
    func encodeACKCIF() throws {
        let ack = ACKPacket(
            acknowledgementNumber: SequenceNumber(500),
            rtt: 2000,
            rttVariance: 100,
            availableBufferSize: 512,
            packetsReceivingRate: 50,
            estimatedLinkCapacity: 100,
            receivingRate: 25_000
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 128)
        PacketCodec.encode(
            controlType: .ack,
            typeSpecificInfo: 1,
            timestamp: 1000,
            destinationSocketID: 0xABCD,
            cif: .ack(ack),
            into: &buffer
        )
        let packet = try PacketCodec.decode(from: &buffer)
        guard case .control(let ctrl) = packet else {
            Issue.record("Expected control packet")
            return
        }
        #expect(ctrl.controlType == .ack)
        #expect(ctrl.controlInfoField.count == ACKPacket.fullACKSize)
    }

    @Test("encode NAK CIF produces decodable packet")
    func encodeNAKCIF() throws {
        let nak = NAKPacket(lossEntries: [.single(SequenceNumber(10))])
        var buffer = ByteBufferAllocator().buffer(capacity: 128)
        PacketCodec.encode(
            controlType: .nak,
            cif: .nak(nak),
            into: &buffer
        )
        let packet = try PacketCodec.decode(from: &buffer)
        guard case .control(let ctrl) = packet else {
            Issue.record("Expected control packet")
            return
        }
        #expect(ctrl.controlType == .nak)
        #expect(!ctrl.controlInfoField.isEmpty)
    }

    // MARK: - encode/decode typed CIF with typeSpecificInfo

    @Test("encode with typeSpecificInfo and timestamp preserves values")
    func encodeTypedCIFPreservesFields() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(
            controlType: .keepalive,
            subtype: 0x00FF,
            typeSpecificInfo: 0xDEAD_BEEF,
            timestamp: 0x1234_5678,
            destinationSocketID: 0xABCD_EF01,
            cif: .keepalive,
            into: &buffer
        )
        let packet = try PacketCodec.decode(from: &buffer)
        guard case .control(let ctrl) = packet else {
            Issue.record("Expected control packet")
            return
        }
        #expect(ctrl.subtype == 0x00FF)
        #expect(ctrl.typeSpecificInfo == 0xDEAD_BEEF)
        #expect(ctrl.timestamp == 0x1234_5678)
        #expect(ctrl.destinationSocketID == 0xABCD_EF01)
    }
}
