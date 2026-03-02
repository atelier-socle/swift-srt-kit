// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("NAKPacket Tests")
struct NAKPacketTests {
    @Test("Single loss entry encode/decode")
    func singleEntry() throws {
        let nak = NAKPacket(lossEntries: [.single(SequenceNumber(42))])
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        nak.encode(into: &buffer)
        let decoded = try NAKPacket.decode(from: &buffer, cifLength: buffer.readableBytes)
        #expect(decoded == nak)
    }

    @Test("Multiple single entries")
    func multipleSingleEntries() throws {
        let nak = NAKPacket(lossEntries: [
            .single(SequenceNumber(10)),
            .single(SequenceNumber(20)),
            .single(SequenceNumber(30))
        ])
        var buffer = ByteBufferAllocator().buffer(capacity: 32)
        nak.encode(into: &buffer)
        let decoded = try NAKPacket.decode(from: &buffer, cifLength: buffer.readableBytes)
        #expect(decoded == nak)
    }

    @Test("Range entry encode/decode")
    func rangeEntry() throws {
        let nak = NAKPacket(lossEntries: [.range(from: SequenceNumber(100), to: SequenceNumber(110))])
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        nak.encode(into: &buffer)
        let decoded = try NAKPacket.decode(from: &buffer, cifLength: buffer.readableBytes)
        #expect(decoded == nak)
    }

    @Test("Mixed single and range entries")
    func mixedEntries() throws {
        let nak = NAKPacket(lossEntries: [
            .single(SequenceNumber(5)),
            .range(from: SequenceNumber(10), to: SequenceNumber(15)),
            .single(SequenceNumber(20))
        ])
        var buffer = ByteBufferAllocator().buffer(capacity: 32)
        nak.encode(into: &buffer)
        let decoded = try NAKPacket.decode(from: &buffer, cifLength: buffer.readableBytes)
        #expect(decoded == nak)
    }

    @Test("Empty loss list")
    func emptyLossList() throws {
        let nak = NAKPacket(lossEntries: [])
        var buffer = ByteBufferAllocator().buffer(capacity: 4)
        nak.encode(into: &buffer)
        let decoded = try NAKPacket.decode(from: &buffer, cifLength: buffer.readableBytes)
        #expect(decoded.lossEntries.isEmpty)
    }

    @Test("Range encoding: bit 31 set for range start")
    func rangeBit31Set() {
        let nak = NAKPacket(lossEntries: [.range(from: SequenceNumber(100), to: SequenceNumber(200))])
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        nak.encode(into: &buffer)
        let firstWord = buffer.getInteger(at: 0, as: UInt32.self)
        #expect(firstWord != nil)
        if let word = firstWord {
            #expect((word & 0x8000_0000) != 0, "Bit 31 should be set for range start")
            #expect((word & 0x7FFF_FFFF) == 100)
        }
    }

    @Test("Single entry: bit 31 clear")
    func singleBit31Clear() {
        let nak = NAKPacket(lossEntries: [.single(SequenceNumber(100))])
        var buffer = ByteBufferAllocator().buffer(capacity: 8)
        nak.encode(into: &buffer)
        let word = buffer.getInteger(at: 0, as: UInt32.self)
        #expect(word != nil)
        if let w = word {
            #expect((w & 0x8000_0000) == 0, "Bit 31 should be clear for single entry")
        }
    }

    @Test("lostSequenceNumbers expansion single")
    func lostSeqSingle() {
        let nak = NAKPacket(lossEntries: [.single(SequenceNumber(42))])
        let lost = nak.lostSequenceNumbers
        #expect(lost.count == 1)
        #expect(lost[0] == SequenceNumber(42))
    }

    @Test("lostSequenceNumbers expansion range")
    func lostSeqRange() {
        let nak = NAKPacket(lossEntries: [.range(from: SequenceNumber(10), to: SequenceNumber(14))])
        let lost = nak.lostSequenceNumbers
        #expect(lost.count == 5)
        #expect(lost[0] == SequenceNumber(10))
        #expect(lost[4] == SequenceNumber(14))
    }

    @Test("lostSequenceNumbers mixed expansion")
    func lostSeqMixed() {
        let nak = NAKPacket(lossEntries: [
            .single(SequenceNumber(1)),
            .range(from: SequenceNumber(10), to: SequenceNumber(12))
        ])
        let lost = nak.lostSequenceNumbers
        #expect(lost.count == 4)
    }

    @Test("Large loss list")
    func largeLossList() throws {
        var entries: [NAKPacket.LossEntry] = []
        for i: UInt32 in 0..<50 {
            entries.append(.single(SequenceNumber(i * 10)))
        }
        let nak = NAKPacket(lossEntries: entries)
        var buffer = ByteBufferAllocator().buffer(capacity: 256)
        nak.encode(into: &buffer)
        let decoded = try NAKPacket.decode(from: &buffer, cifLength: buffer.readableBytes)
        #expect(decoded.lossEntries.count == 50)
    }

    @Test("Roundtrip with known bytes")
    func roundtripKnownBytes() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 12)
        // Single: seq 42
        buffer.writeInteger(UInt32(42))
        // Range: 100-110
        buffer.writeInteger(UInt32(100 | 0x8000_0000))
        buffer.writeInteger(UInt32(110))

        let decoded = try NAKPacket.decode(from: &buffer, cifLength: 12)
        #expect(decoded.lossEntries.count == 2)
        if case .single(let s) = decoded.lossEntries[0] {
            #expect(s.value == 42)
        }
        if case .range(let from, let to) = decoded.lossEntries[1] {
            #expect(from.value == 100)
            #expect(to.value == 110)
        }
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = NAKPacket(lossEntries: [.single(SequenceNumber(1))])
        let b = NAKPacket(lossEntries: [.single(SequenceNumber(1))])
        let c = NAKPacket(lossEntries: [.single(SequenceNumber(2))])
        #expect(a == b)
        #expect(a != c)
    }

    @Test("Single packet encoded size is 4 bytes")
    func singleEncodedSize() {
        let nak = NAKPacket(lossEntries: [.single(SequenceNumber(1))])
        var buffer = ByteBufferAllocator().buffer(capacity: 8)
        nak.encode(into: &buffer)
        #expect(buffer.readableBytes == 4)
    }

    @Test("Range encoded size is 8 bytes")
    func rangeEncodedSize() {
        let nak = NAKPacket(lossEntries: [.range(from: SequenceNumber(1), to: SequenceNumber(10))])
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        nak.encode(into: &buffer)
        #expect(buffer.readableBytes == 8)
    }
}
