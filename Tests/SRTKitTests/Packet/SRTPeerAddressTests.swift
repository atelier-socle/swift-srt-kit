// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("SRTPeerAddress Tests")
struct SRTPeerAddressTests {
    @Test("IPv4 encode/decode roundtrip")
    func ipv4Roundtrip() throws {
        let addr = SRTPeerAddress.ipv4(0xC0A8_0101)  // 192.168.1.1
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        addr.encode(into: &buffer)
        let decoded = try SRTPeerAddress.decode(from: &buffer)
        #expect(decoded == addr)
    }

    @Test("IPv6 encode/decode roundtrip")
    func ipv6Roundtrip() throws {
        let addr = SRTPeerAddress.ipv6(0x2001_0DB8_0000_0001, 0x0000_0000_0000_0001)
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        addr.encode(into: &buffer)
        let decoded = try SRTPeerAddress.decode(from: &buffer)
        #expect(decoded == addr)
    }

    @Test("IPv4-mapped format bytes verification")
    func ipv4MappedBytesVerification() {
        let addr = SRTPeerAddress.ipv4(0x7F00_0001)  // 127.0.0.1
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        addr.encode(into: &buffer)

        // Bytes 0-7: all zeros
        #expect(buffer.getInteger(at: 0, as: UInt64.self) == 0)
        // Bytes 8-11: 0x0000FFFF
        #expect(buffer.getInteger(at: 8, as: UInt32.self) == 0x0000_FFFF)
        // Bytes 12-15: 127.0.0.1
        #expect(buffer.getInteger(at: 12, as: UInt32.self) == 0x7F00_0001)
    }

    @Test("Loopback IPv4 (127.0.0.1)")
    func loopbackIPv4() throws {
        let addr = SRTPeerAddress.ipv4(0x7F00_0001)
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        addr.encode(into: &buffer)
        let decoded = try SRTPeerAddress.decode(from: &buffer)
        if case .ipv4(let val) = decoded {
            #expect(val == 0x7F00_0001)
        } else {
            #expect(Bool(false), "Expected IPv4")
        }
    }

    @Test("All-zeros address decodes as IPv6")
    func allZerosAddress() throws {
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        buffer.writeInteger(UInt64(0))
        buffer.writeInteger(UInt64(0))
        let decoded = try SRTPeerAddress.decode(from: &buffer)
        #expect(decoded == .ipv6(0, 0))
    }

    @Test("Equality comparison")
    func equalityComparison() {
        #expect(SRTPeerAddress.ipv4(0x0A00_0001) == .ipv4(0x0A00_0001))
        #expect(SRTPeerAddress.ipv4(0x0A00_0001) != .ipv4(0x0A00_0002))
        #expect(SRTPeerAddress.ipv6(1, 2) == .ipv6(1, 2))
        #expect(SRTPeerAddress.ipv6(1, 2) != .ipv6(1, 3))
    }

    @Test("Buffer too small throws error")
    func bufferTooSmall() {
        var buffer = ByteBufferAllocator().buffer(capacity: 4)
        buffer.writeInteger(UInt32(0))
        #expect(throws: SRTError.self) {
            try SRTPeerAddress.decode(from: &buffer)
        }
    }

    @Test("Hashable conformance")
    func hashable() {
        let set: Set<SRTPeerAddress> = [.ipv4(1), .ipv4(2), .ipv4(1)]
        #expect(set.count == 2)
    }

    @Test("IPv4 address 0.0.0.0 in mapped format")
    func ipv4ZeroMapped() throws {
        let addr = SRTPeerAddress.ipv4(0)
        var buffer = ByteBufferAllocator().buffer(capacity: 16)
        addr.encode(into: &buffer)
        let decoded = try SRTPeerAddress.decode(from: &buffer)
        #expect(decoded == .ipv4(0))
    }
}
