// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("XORHelper Tests")
struct XORHelperTests {
    @Test("XOR two equal-length arrays")
    func xorEqualLength() {
        let a: [UInt8] = [0xFF, 0x00, 0xAA]
        let b: [UInt8] = [0x0F, 0xF0, 0x55]
        let result = XORHelper.xor(a, b)
        #expect(result == [0xF0, 0xF0, 0xFF])
    }

    @Test("XOR two different-length arrays pads shorter")
    func xorDifferentLength() {
        let a: [UInt8] = [0xFF, 0x00]
        let b: [UInt8] = [0x0F, 0xF0, 0xAA]
        let result = XORHelper.xor(a, b)
        #expect(result == [0xF0, 0xF0, 0xAA])
    }

    @Test("XOR with empty array returns other")
    func xorWithEmpty() {
        let a: [UInt8] = [0xFF, 0xAA]
        let result = XORHelper.xor(a, [])
        #expect(result == [0xFF, 0xAA])
    }

    @Test("XOR with self produces all zeros")
    func xorWithSelf() {
        let a: [UInt8] = [0xFF, 0xAA, 0x55]
        let result = XORHelper.xor(a, a)
        #expect(result == [0x00, 0x00, 0x00])
    }

    @Test("xorInPlace accumulates correctly")
    func xorInPlace() {
        var acc: [UInt8] = [0xFF, 0x00]
        XORHelper.xorInPlace(&acc, [0x0F, 0xF0])
        #expect(acc == [0xF0, 0xF0])
        XORHelper.xorInPlace(&acc, [0xF0, 0xF0])
        #expect(acc == [0x00, 0x00])
    }

    @Test("xorInPlace extends accumulator")
    func xorInPlaceExtends() {
        var acc: [UInt8] = [0xFF]
        XORHelper.xorInPlace(&acc, [0x0F, 0xAA, 0x55])
        #expect(acc == [0xF0, 0xAA, 0x55])
    }

    @Test("xorAll with 3 arrays")
    func xorAllThree() {
        let arrays: [[UInt8]] = [
            [0xFF, 0x00],
            [0x0F, 0xF0],
            [0xF0, 0x0F]
        ]
        let result = XORHelper.xorAll(arrays)
        // 0xFF ^ 0x0F ^ 0xF0 = 0x00, 0x00 ^ 0xF0 ^ 0x0F = 0xFF
        #expect(result == [0x00, 0xFF])
    }

    @Test("xorAll with single array returns same")
    func xorAllSingle() {
        let result = XORHelper.xorAll([[0xFF, 0xAA]])
        #expect(result == [0xFF, 0xAA])
    }

    @Test("xorAll with empty list returns empty")
    func xorAllEmpty() {
        let result = XORHelper.xorAll([])
        #expect(result.isEmpty)
    }

    @Test("Large payload XOR (1316 bytes)")
    func largePayload() {
        let a = [UInt8](repeating: 0xFF, count: 1316)
        let b = [UInt8](repeating: 0xAA, count: 1316)
        let result = XORHelper.xor(a, b)
        #expect(result.count == 1316)
        #expect(result.allSatisfy { $0 == 0x55 })
    }
}
