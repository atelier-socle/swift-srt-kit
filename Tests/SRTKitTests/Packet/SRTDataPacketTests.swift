// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("SRTDataPacket Tests")
struct SRTDataPacketTests {
    // MARK: - Creation

    @Test("Create with defaults")
    func createWithDefaults() {
        let packet = SRTDataPacket(sequenceNumber: SequenceNumber(1))
        #expect(packet.sequenceNumber.value == 1)
        #expect(packet.position == .single)
        #expect(packet.orderFlag == false)
        #expect(packet.encryptionKey == .none)
        #expect(packet.retransmitted == false)
        #expect(packet.messageNumber == 0)
        #expect(packet.timestamp == 0)
        #expect(packet.destinationSocketID == 0)
        #expect(packet.payload.isEmpty)
    }

    @Test("Create with all fields set")
    func createWithAllFields() {
        let packet = SRTDataPacket(
            sequenceNumber: SequenceNumber(100),
            position: .first,
            orderFlag: true,
            encryptionKey: .even,
            retransmitted: true,
            messageNumber: 42,
            timestamp: 1000,
            destinationSocketID: 0xDEAD_BEEF,
            payload: [0x01, 0x02, 0x03]
        )
        #expect(packet.sequenceNumber.value == 100)
        #expect(packet.position == .first)
        #expect(packet.orderFlag == true)
        #expect(packet.encryptionKey == .even)
        #expect(packet.retransmitted == true)
        #expect(packet.messageNumber == 42)
        #expect(packet.timestamp == 1000)
        #expect(packet.destinationSocketID == 0xDEAD_BEEF)
        #expect(packet.payload == [0x01, 0x02, 0x03])
    }

    // MARK: - Position

    @Test("All Position cases have correct raw values")
    func positionRawValues() {
        #expect(SRTDataPacket.Position.first.rawValue == 0b10)
        #expect(SRTDataPacket.Position.middle.rawValue == 0b00)
        #expect(SRTDataPacket.Position.last.rawValue == 0b01)
        #expect(SRTDataPacket.Position.single.rawValue == 0b11)
    }

    @Test("All Position cases are iterable")
    func positionCaseIterable() {
        #expect(SRTDataPacket.Position.allCases.count == 4)
    }

    @Test("Position descriptions are correct")
    func positionDescriptions() {
        #expect(SRTDataPacket.Position.first.description == "first")
        #expect(SRTDataPacket.Position.middle.description == "middle")
        #expect(SRTDataPacket.Position.last.description == "last")
        #expect(SRTDataPacket.Position.single.description == "single")
    }

    // MARK: - EncryptionKey

    @Test("All EncryptionKey cases have correct raw values")
    func encryptionKeyRawValues() {
        #expect(SRTDataPacket.EncryptionKey.none.rawValue == 0b00)
        #expect(SRTDataPacket.EncryptionKey.even.rawValue == 0b01)
        #expect(SRTDataPacket.EncryptionKey.odd.rawValue == 0b10)
        #expect(SRTDataPacket.EncryptionKey.controlOnly.rawValue == 0b11)
    }

    @Test("All EncryptionKey cases are iterable")
    func encryptionKeyCaseIterable() {
        #expect(SRTDataPacket.EncryptionKey.allCases.count == 4)
    }

    @Test("EncryptionKey descriptions are correct")
    func encryptionKeyDescriptions() {
        #expect(SRTDataPacket.EncryptionKey.none.description == "none")
        #expect(SRTDataPacket.EncryptionKey.even.description == "even")
        #expect(SRTDataPacket.EncryptionKey.odd.description == "odd")
        #expect(SRTDataPacket.EncryptionKey.controlOnly.description == "controlOnly")
    }

    // MARK: - Encode/Decode Roundtrip

    @Test("Roundtrip with all Position values", arguments: SRTDataPacket.Position.allCases)
    func roundtripAllPositions(position: SRTDataPacket.Position) throws {
        let original = SRTDataPacket(
            sequenceNumber: SequenceNumber(42),
            position: position,
            payload: [0xAA, 0xBB]
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.data(original), into: &buffer)
        let decoded = try PacketCodec.decode(from: &buffer)
        guard case .data(let result) = decoded else {
            #expect(Bool(false), "Expected data packet")
            return
        }
        #expect(result.position == position)
        #expect(result.sequenceNumber == original.sequenceNumber)
        #expect(result.payload == original.payload)
    }

    @Test("Roundtrip with all EncryptionKey values", arguments: SRTDataPacket.EncryptionKey.allCases)
    func roundtripAllEncryptionKeys(key: SRTDataPacket.EncryptionKey) throws {
        let original = SRTDataPacket(
            sequenceNumber: SequenceNumber(99),
            encryptionKey: key,
            payload: [0xCC]
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.data(original), into: &buffer)
        let decoded = try PacketCodec.decode(from: &buffer)
        guard case .data(let result) = decoded else {
            #expect(Bool(false), "Expected data packet")
            return
        }
        #expect(result.encryptionKey == key)
    }

    @Test("Roundtrip with order and retransmit flags")
    func roundtripFlags() throws {
        let original = SRTDataPacket(
            sequenceNumber: SequenceNumber(1),
            orderFlag: true,
            retransmitted: true,
            messageNumber: 123,
            timestamp: 5000,
            destinationSocketID: 0x1234
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.data(original), into: &buffer)
        let decoded = try PacketCodec.decode(from: &buffer)
        guard case .data(let result) = decoded else {
            #expect(Bool(false), "Expected data packet")
            return
        }
        #expect(result.orderFlag == true)
        #expect(result.retransmitted == true)
        #expect(result.messageNumber == 123)
        #expect(result.timestamp == 5000)
        #expect(result.destinationSocketID == 0x1234)
    }

    @Test("Roundtrip with max message number")
    func roundtripMaxMessageNumber() throws {
        let original = SRTDataPacket(
            sequenceNumber: SequenceNumber(0),
            messageNumber: SRTDataPacket.maxMessageNumber
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.data(original), into: &buffer)
        let decoded = try PacketCodec.decode(from: &buffer)
        guard case .data(let result) = decoded else {
            #expect(Bool(false), "Expected data packet")
            return
        }
        #expect(result.messageNumber == SRTDataPacket.maxMessageNumber)
    }

    @Test("Message number masks to 26 bits")
    func messageNumberMasking() {
        let packet = SRTDataPacket(
            sequenceNumber: SequenceNumber(0),
            messageNumber: 0xFFFF_FFFF
        )
        #expect(packet.messageNumber == SRTDataPacket.maxMessageNumber)
    }

    @Test("Roundtrip with empty payload")
    func roundtripEmptyPayload() throws {
        let original = SRTDataPacket(
            sequenceNumber: SequenceNumber(77),
            payload: []
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.data(original), into: &buffer)
        let decoded = try PacketCodec.decode(from: &buffer)
        guard case .data(let result) = decoded else {
            #expect(Bool(false), "Expected data packet")
            return
        }
        #expect(result.payload.isEmpty)
    }

    @Test("Roundtrip preserves all fields")
    func roundtripFullPreservation() throws {
        let original = SRTDataPacket(
            sequenceNumber: SequenceNumber(0x7FFF_FFFF),
            position: .last,
            orderFlag: true,
            encryptionKey: .odd,
            retransmitted: true,
            messageNumber: 0x03FF_FFFF,
            timestamp: 0xFFFF_FFFF,
            destinationSocketID: 0xABCD_EF01,
            payload: Array(0..<100)
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 256)
        PacketCodec.encode(.data(original), into: &buffer)
        let decoded = try PacketCodec.decode(from: &buffer)
        guard case .data(let result) = decoded else {
            #expect(Bool(false), "Expected data packet")
            return
        }
        #expect(result == original)
    }

    // MARK: - Hashable

    @Test("Hashable conformance for identical packets")
    func hashableIdentical() {
        let a = SRTDataPacket(sequenceNumber: SequenceNumber(1), payload: [0x01])
        let b = SRTDataPacket(sequenceNumber: SequenceNumber(1), payload: [0x01])
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("Different packets are not equal")
    func differentPacketsNotEqual() {
        let a = SRTDataPacket(sequenceNumber: SequenceNumber(1))
        let b = SRTDataPacket(sequenceNumber: SequenceNumber(2))
        #expect(a != b)
    }
}
