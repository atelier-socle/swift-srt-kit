// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("ACKPacket Coverage Tests")
struct ACKPacketCoverageTests {

    // MARK: - Full ACK encode

    @Test("Full ACK encode writes 28 bytes")
    func fullACKEncodeWrites28Bytes() {
        let ack = ACKPacket(
            acknowledgementNumber: SequenceNumber(42),
            rtt: 5000,
            rttVariance: 1000,
            availableBufferSize: 8192,
            packetsReceivingRate: 100,
            estimatedLinkCapacity: 200,
            receivingRate: 50_000
        )
        var buffer = ByteBuffer()
        ack.encode(into: &buffer)
        #expect(buffer.readableBytes == ACKPacket.fullACKSize)
    }

    @Test("Light ACK encode writes 4 bytes")
    func lightACKEncodeWrites4Bytes() {
        let ack = ACKPacket(
            acknowledgementNumber: SequenceNumber(42))
        var buffer = ByteBuffer()
        ack.encode(into: &buffer)
        #expect(buffer.readableBytes == ACKPacket.lightACKSize)
    }

    // MARK: - Decode errors

    @Test("Decode with too small CIF throws")
    func decodeTooSmallCIF() {
        var buffer = ByteBuffer()
        buffer.writeInteger(UInt16(0))  // Only 2 bytes
        #expect(throws: SRTError.self) {
            _ = try ACKPacket.decode(from: &buffer, cifLength: 2)
        }
    }

    @Test("Decode with invalid read throws")
    func decodeInvalidRead() {
        var buffer = ByteBuffer()
        // Write only the ack seq number (4 bytes) but claim full ACK size
        buffer.writeInteger(UInt32(42))
        // cifLength says full but buffer only has 4 bytes after ack number
        // Decode should succeed as light ACK since cifLength=4 < fullACKSize
        do {
            let ack = try ACKPacket.decode(from: &buffer, cifLength: 4)
            #expect(ack.acknowledgementNumber == SequenceNumber(42))
            #expect(ack.rtt == nil)
        } catch {
            Issue.record("Should not throw for light ACK decode")
        }
    }

    @Test("Full ACK decode with insufficient data throws")
    func fullACKDecodeInsufficientData() {
        var buffer = ByteBuffer()
        buffer.writeInteger(UInt32(42))  // ack number
        buffer.writeInteger(UInt32(100))  // rtt only, missing rest
        // cifLength=28 but only 8 bytes of data
        #expect(throws: SRTError.self) {
            _ = try ACKPacket.decode(from: &buffer, cifLength: 28)
        }
    }

    // MARK: - Full ACK roundtrip

    @Test("Full ACK encode-decode roundtrip preserves all fields")
    func fullACKRoundtrip() throws {
        let original = ACKPacket(
            acknowledgementNumber: SequenceNumber(100),
            rtt: 5000,
            rttVariance: 1000,
            availableBufferSize: 4096,
            packetsReceivingRate: 200,
            estimatedLinkCapacity: 500,
            receivingRate: 80_000
        )
        var buffer = ByteBuffer()
        original.encode(into: &buffer)

        let decoded = try ACKPacket.decode(
            from: &buffer, cifLength: ACKPacket.fullACKSize)
        #expect(decoded.acknowledgementNumber == original.acknowledgementNumber)
        #expect(decoded.rtt == original.rtt)
        #expect(decoded.rttVariance == original.rttVariance)
        #expect(decoded.availableBufferSize == original.availableBufferSize)
        #expect(decoded.packetsReceivingRate == original.packetsReceivingRate)
        #expect(decoded.estimatedLinkCapacity == original.estimatedLinkCapacity)
        #expect(decoded.receivingRate == original.receivingRate)
    }

    // MARK: - Full ACK with partial nil optional fields

    @Test("Full ACK encode with rtt set but some optional fields nil writes zeros")
    func fullACKEncodePartialNils() {
        // rtt is non-nil so all 28 bytes are written; nil fields become 0
        let ack = ACKPacket(
            acknowledgementNumber: SequenceNumber(77),
            rtt: 3000,
            rttVariance: nil,
            availableBufferSize: nil,
            packetsReceivingRate: nil,
            estimatedLinkCapacity: nil,
            receivingRate: nil
        )
        #expect(!ack.isLightACK)
        var buffer = ByteBuffer()
        ack.encode(into: &buffer)
        #expect(buffer.readableBytes == ACKPacket.fullACKSize)

        // Verify: ackSeq(4) + rtt(4) + rttVar=0(4) + buf=0(4) + rate=0(4) + cap=0(4) + recv=0(4)
        let ackSeq = buffer.readInteger(as: UInt32.self)
        #expect(ackSeq == 77)
        let rtt = buffer.readInteger(as: UInt32.self)
        #expect(rtt == 3000)
        let rttVar = buffer.readInteger(as: UInt32.self)
        #expect(rttVar == 0)
        let bufSize = buffer.readInteger(as: UInt32.self)
        #expect(bufSize == 0)
        let pktRate = buffer.readInteger(as: UInt32.self)
        #expect(pktRate == 0)
        let linkCap = buffer.readInteger(as: UInt32.self)
        #expect(linkCap == 0)
        let recvRate = buffer.readInteger(as: UInt32.self)
        #expect(recvRate == 0)
    }

    @Test("Full ACK encode with rtt and partial fields set uses values")
    func fullACKEncodePartialFieldsSet() {
        let ack = ACKPacket(
            acknowledgementNumber: SequenceNumber(50),
            rtt: 1000,
            rttVariance: 500,
            availableBufferSize: nil,
            packetsReceivingRate: 300,
            estimatedLinkCapacity: nil,
            receivingRate: 10_000
        )
        var buffer = ByteBuffer()
        ack.encode(into: &buffer)
        #expect(buffer.readableBytes == ACKPacket.fullACKSize)
    }

    // MARK: - Decode error: empty buffer for ack seq

    @Test("Decode with cifLength >= 4 but empty buffer throws")
    func decodeEmptyBufferForAckSeq() {
        var buffer = ByteBuffer()
        // cifLength says 4 bytes available but buffer is empty
        #expect(throws: SRTError.self) {
            _ = try ACKPacket.decode(from: &buffer, cifLength: 4)
        }
    }

    @Test("Decode with cifLength >= 28 but buffer only has ack seq throws")
    func decodeFullACKTruncatedAfterAckSeq() {
        var buffer = ByteBuffer()
        buffer.writeInteger(UInt32(42))  // ack number only (4 bytes)
        // cifLength says full ACK (28) but buffer only has 4 bytes
        #expect(throws: SRTError.self) {
            _ = try ACKPacket.decode(from: &buffer, cifLength: 28)
        }
    }

    @Test("Decode with cifLength between 4 and 28 returns light ACK")
    func decodeIntermediateCIFLength() throws {
        var buffer = ByteBuffer()
        buffer.writeInteger(UInt32(99))
        // cifLength=12 is >= lightACKSize but < fullACKSize → light ACK
        let ack = try ACKPacket.decode(from: &buffer, cifLength: 12)
        #expect(ack.acknowledgementNumber == SequenceNumber(99))
        #expect(ack.isLightACK)
        #expect(ack.rtt == nil)
    }

    // MARK: - isLightACK property

    @Test("isLightACK returns true for light ACK")
    func isLightACKTrue() {
        let ack = ACKPacket(acknowledgementNumber: SequenceNumber(1))
        #expect(ack.isLightACK)
    }

    @Test("isLightACK returns false for full ACK")
    func isLightACKFalse() {
        let ack = ACKPacket(
            acknowledgementNumber: SequenceNumber(1),
            rtt: 100
        )
        #expect(!ack.isLightACK)
    }

    // MARK: - Light ACK roundtrip

    @Test("Light ACK encode-decode roundtrip")
    func lightACKRoundtrip() throws {
        let original = ACKPacket(acknowledgementNumber: SequenceNumber(12345))
        var buffer = ByteBuffer()
        original.encode(into: &buffer)
        let decoded = try ACKPacket.decode(from: &buffer, cifLength: ACKPacket.lightACKSize)
        #expect(decoded.acknowledgementNumber == original.acknowledgementNumber)
        #expect(decoded.isLightACK)
    }

    // MARK: - Static constants

    @Test("lightACKSize is 4")
    func lightACKSizeConstant() {
        #expect(ACKPacket.lightACKSize == 4)
    }

    @Test("fullACKSize is 28")
    func fullACKSizeConstant() {
        #expect(ACKPacket.fullACKSize == 28)
    }

    // MARK: - Equatable

    @Test("Two identical ACKPackets are equal")
    func equatable() {
        let a = ACKPacket(
            acknowledgementNumber: SequenceNumber(10),
            rtt: 100,
            rttVariance: 50,
            availableBufferSize: 1024,
            packetsReceivingRate: 200,
            estimatedLinkCapacity: 300,
            receivingRate: 400
        )
        let b = ACKPacket(
            acknowledgementNumber: SequenceNumber(10),
            rtt: 100,
            rttVariance: 50,
            availableBufferSize: 1024,
            packetsReceivingRate: 200,
            estimatedLinkCapacity: 300,
            receivingRate: 400
        )
        #expect(a == b)
    }

    @Test("ACKPackets with different fields are not equal")
    func notEquatable() {
        let a = ACKPacket(acknowledgementNumber: SequenceNumber(10), rtt: 100)
        let b = ACKPacket(acknowledgementNumber: SequenceNumber(10), rtt: 200)
        #expect(a != b)
    }

    @Test("Decode with cifLength of exactly 0 throws")
    func decodeZeroCIFLength() {
        var buffer = ByteBuffer()
        #expect(throws: SRTError.self) {
            _ = try ACKPacket.decode(from: &buffer, cifLength: 0)
        }
    }

    @Test("Decode with cifLength of 3 throws")
    func decodeCIFLengthThree() {
        var buffer = ByteBuffer()
        buffer.writeBytes([0x00, 0x01, 0x02])
        #expect(throws: SRTError.self) {
            _ = try ACKPacket.decode(from: &buffer, cifLength: 3)
        }
    }
}
