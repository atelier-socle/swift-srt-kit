// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("SRTControlPacket Tests")
struct SRTControlPacketTests {
    @Test("Create with defaults")
    func createWithDefaults() {
        let packet = SRTControlPacket(controlType: .handshake)
        #expect(packet.controlType == .handshake)
        #expect(packet.subtype == 0)
        #expect(packet.typeSpecificInfo == 0)
        #expect(packet.timestamp == 0)
        #expect(packet.destinationSocketID == 0)
        #expect(packet.controlInfoField.isEmpty)
    }

    @Test("Roundtrip for each ControlType", arguments: ControlType.allCases)
    func roundtripAllControlTypes(controlType: ControlType) throws {
        let original = SRTControlPacket(
            controlType: controlType,
            subtype: 0,
            typeSpecificInfo: 42,
            timestamp: 1000,
            destinationSocketID: 0xABCD
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.control(original), into: &buffer)
        let decoded = try PacketCodec.decode(from: &buffer)
        guard case .control(let result) = decoded else {
            #expect(Bool(false), "Expected control packet")
            return
        }
        #expect(result.controlType == controlType)
        #expect(result.typeSpecificInfo == 42)
        #expect(result.timestamp == 1000)
        #expect(result.destinationSocketID == 0xABCD)
    }

    @Test("Roundtrip preserves subtype")
    func roundtripSubtype() throws {
        let original = SRTControlPacket(
            controlType: .handshake,
            subtype: 0x1234
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.control(original), into: &buffer)
        let decoded = try PacketCodec.decode(from: &buffer)
        guard case .control(let result) = decoded else {
            #expect(Bool(false), "Expected control packet")
            return
        }
        #expect(result.subtype == 0x1234)
    }

    @Test("Roundtrip preserves typeSpecificInfo")
    func roundtripTypeSpecificInfo() throws {
        let original = SRTControlPacket(
            controlType: .ack,
            typeSpecificInfo: 0xDEAD_BEEF
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.control(original), into: &buffer)
        let decoded = try PacketCodec.decode(from: &buffer)
        guard case .control(let result) = decoded else {
            #expect(Bool(false), "Expected control packet")
            return
        }
        #expect(result.typeSpecificInfo == 0xDEAD_BEEF)
    }

    @Test("Roundtrip preserves CIF")
    func roundtripCIF() throws {
        let cif: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05]
        let original = SRTControlPacket(
            controlType: .handshake,
            controlInfoField: cif
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.control(original), into: &buffer)
        let decoded = try PacketCodec.decode(from: &buffer)
        guard case .control(let result) = decoded else {
            #expect(Bool(false), "Expected control packet")
            return
        }
        #expect(result.controlInfoField == cif)
    }

    @Test("Roundtrip with empty CIF")
    func roundtripEmptyCIF() throws {
        let original = SRTControlPacket(controlType: .keepalive)
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        PacketCodec.encode(.control(original), into: &buffer)
        let decoded = try PacketCodec.decode(from: &buffer)
        guard case .control(let result) = decoded else {
            #expect(Bool(false), "Expected control packet")
            return
        }
        #expect(result.controlInfoField.isEmpty)
    }

    @Test("Roundtrip preserves all fields")
    func roundtripFullPreservation() throws {
        let original = SRTControlPacket(
            controlType: .nak,
            subtype: 0xFFFF,
            typeSpecificInfo: 0xFFFF_FFFF,
            timestamp: 0xFFFF_FFFF,
            destinationSocketID: 0xFFFF_FFFF,
            controlInfoField: Array(0..<50)
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 128)
        PacketCodec.encode(.control(original), into: &buffer)
        let decoded = try PacketCodec.decode(from: &buffer)
        guard case .control(let result) = decoded else {
            #expect(Bool(false), "Expected control packet")
            return
        }
        #expect(result == original)
    }

    // MARK: - ControlType

    @Test("All ControlType cases count")
    func controlTypeCaseCount() {
        #expect(ControlType.allCases.count == 10)
    }

    @Test("ControlType descriptions are non-empty")
    func controlTypeDescriptions() {
        for ct in ControlType.allCases {
            #expect(!ct.description.isEmpty)
        }
    }

    @Test("ControlType raw values")
    func controlTypeRawValues() {
        #expect(ControlType.handshake.rawValue == 0x0000)
        #expect(ControlType.keepalive.rawValue == 0x0001)
        #expect(ControlType.ack.rawValue == 0x0002)
        #expect(ControlType.nak.rawValue == 0x0003)
        #expect(ControlType.congestion.rawValue == 0x0004)
        #expect(ControlType.shutdown.rawValue == 0x0005)
        #expect(ControlType.ackack.rawValue == 0x0006)
        #expect(ControlType.dropreq.rawValue == 0x0007)
        #expect(ControlType.peererror.rawValue == 0x0008)
        #expect(ControlType.userDefined.rawValue == 0x7FFF)
    }

    // MARK: - Hashable

    @Test("Hashable conformance for identical packets")
    func hashableIdentical() {
        let a = SRTControlPacket(controlType: .ack, typeSpecificInfo: 1)
        let b = SRTControlPacket(controlType: .ack, typeSpecificInfo: 1)
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }
}
