// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("Verify KM Encoding Wire Format")
struct VerifyKMEncodingTest {
    @Test("KM CIF byte layout matches libsrt hcrypt_msg.h")
    func verifyCIFLayout() {
        let salt: [UInt8] = Array(0..<16)
        let wrappedKeys: [UInt8] = Array(repeating: 0xAB, count: 24)

        let km = KeyMaterialPacket(
            cipher: .aesCTR,
            salt: salt,
            keyLength: 16,
            wrappedKeys: wrappedKeys
        )

        var cifBuf = ByteBuffer()
        km.encode(into: &cifBuf)
        let cifBytes = Array(cifBuf.readableBytesView)

        #expect(cifBytes.count == 56, "Expected 56 bytes, got \(cifBytes.count)")
        #expect(cifBytes[0] == 0x12, "Byte 0: V|PT")
        #expect(cifBytes[1] == 0x20, "Byte 1: Sign MSB")
        #expect(cifBytes[2] == 0x29, "Byte 2: Sign LSB")
        #expect(cifBytes[3] == 0x01, "Byte 3: KFLGS")
        #expect(cifBytes[4] == 0x00, "Byte 4: KEKI")
        #expect(cifBytes[7] == 0x00, "Byte 7: KEKI")
        #expect(cifBytes[8] == 0x02, "Byte 8: Cipher")
        #expect(cifBytes[9] == 0x00, "Byte 9: Auth")
        #expect(cifBytes[10] == 0x02, "Byte 10: SE")
        #expect(cifBytes[11] == 0x00, "Byte 11: Reserved")
        #expect(cifBytes[12] == 0x00, "Byte 12: Reserved2")
        #expect(cifBytes[13] == 0x00, "Byte 13: Reserved2")
        #expect(cifBytes[14] == 0x04, "Byte 14: SLen/4")
        #expect(cifBytes[15] == 0x04, "Byte 15: KLen/4")

        for i in 0..<16 {
            #expect(cifBytes[16 + i] == UInt8(i), "Salt[\(i)]")
        }
        for i in 0..<24 {
            #expect(cifBytes[32 + i] == 0xAB, "WrappedKey[\(i)]")
        }
    }

    @Test("KMREQ TLV header has correct type and length")
    func verifyTLVHeader() {
        let salt: [UInt8] = Array(0..<16)
        let wrappedKeys: [UInt8] = Array(repeating: 0xAB, count: 24)

        let km = KeyMaterialPacket(
            cipher: .aesCTR,
            salt: salt,
            keyLength: 16,
            wrappedKeys: wrappedKeys
        )

        let hsreq = SRTHandshakeExtension(
            srtVersion: 0x0001_0501,
            srtFlags: [.tsbpdSender, .tsbpdReceiver, .crypt, .tlpktDrop, .periodicNAK, .rexmitFlag],
            receiverTSBPDDelay: 120,
            senderTSBPDDelay: 120
        )

        let handshake = HandshakePacket(
            version: 5,
            encryptionField: 2,
            extensionField: 3,
            handshakeType: .conclusion,
            srtSocketID: 0x1234
        )

        let fullBuf = HandshakePacketEncoder.encode(
            handshake: handshake,
            extensions: [.hsreq(hsreq), .kmreq(km)],
            destinationSocketID: 0
        )
        let fullBytes = Array(fullBuf.readableBytesView)

        // Expected: header(16) + CIF(48) + HSREQ TLV(4+12) + KMREQ TLV(4+56) = 140
        let expectedTotal = 16 + 48 + 16 + 60
        #expect(fullBytes.count == expectedTotal, "Total: \(fullBytes.count) expected \(expectedTotal)")

        // KMREQ TLV starts after header(16) + CIF(48) + HSREQ TLV(16) = 80
        let kmreqOffset = 80
        let kmreqType = UInt16(fullBytes[kmreqOffset]) << 8 | UInt16(fullBytes[kmreqOffset + 1])
        let kmreqLen = UInt16(fullBytes[kmreqOffset + 2]) << 8 | UInt16(fullBytes[kmreqOffset + 3])

        #expect(kmreqType == 0x0003, "KMREQ type: 0x\(String(format: "%04x", kmreqType))")
        #expect(kmreqLen == 14, "KMREQ len: \(kmreqLen) words (expected 14)")

        // Print hex for visual inspection
        print("KMREQ TLV (60 bytes):")
        for i in kmreqOffset..<min(kmreqOffset + 60, fullBytes.count) {
            let localIdx = i - kmreqOffset
            if localIdx % 16 == 0 { print(String(format: "  %04x: ", localIdx), terminator: "") }
            print(String(format: "%02x ", fullBytes[i]), terminator: "")
            if localIdx % 16 == 15 || i == fullBytes.count - 1 { print() }
        }
        print()
    }
}
