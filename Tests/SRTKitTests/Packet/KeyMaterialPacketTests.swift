// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("KeyMaterialPacket Tests")
struct KeyMaterialPacketTests {
    private func makeSalt() -> [UInt8] {
        Array(0..<16)
    }

    private func makeWrappedKey(length: Int) -> [UInt8] {
        Array(repeating: 0xAB, count: length)
    }

    @Test("AES-128 CTR encode/decode roundtrip")
    func aes128CTRRoundtrip() throws {
        let original = KeyMaterialPacket(
            cipher: .aesCTR,
            salt: makeSalt(),
            keyLength: 16,
            wrappedKeys: makeWrappedKey(length: 24)
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        original.encode(into: &buffer)
        let decoded = try KeyMaterialPacket.decode(from: &buffer, cifLength: buffer.readableBytes)
        #expect(decoded.cipher == .aesCTR)
        #expect(decoded.keyLength == 16)
        #expect(decoded.salt == makeSalt())
        #expect(decoded.wrappedKeys == makeWrappedKey(length: 24))
    }

    @Test("AES-256 CTR encode/decode roundtrip")
    func aes256CTRRoundtrip() throws {
        let original = KeyMaterialPacket(
            cipher: .aesCTR,
            salt: makeSalt(),
            keyLength: 32,
            wrappedKeys: makeWrappedKey(length: 40)
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        original.encode(into: &buffer)
        let decoded = try KeyMaterialPacket.decode(from: &buffer, cifLength: buffer.readableBytes)
        #expect(decoded.keyLength == 32)
    }

    @Test("AES-128 GCM encode/decode roundtrip")
    func aes128GCMRoundtrip() throws {
        let original = KeyMaterialPacket(
            cipher: .aesGCM,
            authentication: 1,
            salt: makeSalt(),
            keyLength: 16,
            wrappedKeys: makeWrappedKey(length: 24)
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        original.encode(into: &buffer)
        let decoded = try KeyMaterialPacket.decode(from: &buffer, cifLength: buffer.readableBytes)
        #expect(decoded.cipher == .aesGCM)
        #expect(decoded.authentication == 1)
    }

    @Test("Sign field preservation (0x2029)")
    func signField() throws {
        let km = KeyMaterialPacket(
            cipher: .aesCTR,
            salt: makeSalt(),
            keyLength: 16,
            wrappedKeys: makeWrappedKey(length: 24)
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        km.encode(into: &buffer)
        let decoded = try KeyMaterialPacket.decode(from: &buffer, cifLength: buffer.readableBytes)
        #expect(decoded.sign == 0x2029)
    }

    @Test("Salt preservation (16 bytes)")
    func saltPreservation() throws {
        let salt: [UInt8] = (0..<16).map { $0 * 3 }
        let km = KeyMaterialPacket(
            cipher: .aesCTR,
            salt: salt,
            keyLength: 16,
            wrappedKeys: makeWrappedKey(length: 24)
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        km.encode(into: &buffer)
        let decoded = try KeyMaterialPacket.decode(from: &buffer, cifLength: buffer.readableBytes)
        #expect(decoded.salt == salt)
    }

    @Test("Single wrapped key (even only)")
    func singleWrappedKey() throws {
        let km = KeyMaterialPacket(
            keyBasedEncryption: 0x01,
            cipher: .aesCTR,
            salt: makeSalt(),
            keyLength: 16,
            wrappedKeys: makeWrappedKey(length: 24)
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        km.encode(into: &buffer)
        let decoded = try KeyMaterialPacket.decode(from: &buffer, cifLength: buffer.readableBytes)
        #expect(decoded.keyBasedEncryption == 0x01)
        #expect(decoded.wrappedKeys.count == 24)
    }

    @Test("Dual wrapped keys (both even and odd)")
    func dualWrappedKeys() throws {
        let km = KeyMaterialPacket(
            keyBasedEncryption: 0x03,
            cipher: .aesCTR,
            salt: makeSalt(),
            keyLength: 16,
            wrappedKeys: makeWrappedKey(length: 48)  // two 24-byte wrapped keys
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 80)
        km.encode(into: &buffer)
        let decoded = try KeyMaterialPacket.decode(from: &buffer, cifLength: buffer.readableBytes)
        #expect(decoded.keyBasedEncryption == 0x03)
        #expect(decoded.wrappedKeys.count == 48)
    }

    @Test("Version and packetType preservation")
    func versionAndPacketType() throws {
        let km = KeyMaterialPacket(
            version: 1,
            packetType: 2,
            cipher: .aesCTR,
            salt: makeSalt(),
            keyLength: 16,
            wrappedKeys: makeWrappedKey(length: 24)
        )
        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        km.encode(into: &buffer)
        let decoded = try KeyMaterialPacket.decode(from: &buffer, cifLength: buffer.readableBytes)
        #expect(decoded.version == 1)
        #expect(decoded.packetType == 2)
    }

    @Test("CipherType enum values")
    func cipherTypeValues() {
        #expect(KeyMaterialPacket.CipherType.none.rawValue == 0)
        #expect(KeyMaterialPacket.CipherType.aesCTR.rawValue == 2)
        #expect(KeyMaterialPacket.CipherType.aesGCM.rawValue == 3)
        #expect(KeyMaterialPacket.CipherType.allCases.count == 3)
    }

    @Test("KMState enum values")
    func kmStateValues() {
        #expect(KeyMaterialPacket.KMState.noSEK.rawValue == 0)
        #expect(KeyMaterialPacket.KMState.secured.rawValue == 1)
        #expect(KeyMaterialPacket.KMState.securing.rawValue == 2)
        #expect(KeyMaterialPacket.KMState.failed.rawValue == 3)
        #expect(KeyMaterialPacket.KMState.verified.rawValue == 4)
        #expect(KeyMaterialPacket.KMState.allCases.count == 5)
    }

    @Test("CipherType descriptions")
    func cipherTypeDescriptions() {
        #expect(KeyMaterialPacket.CipherType.none.description == "none")
        #expect(KeyMaterialPacket.CipherType.aesCTR.description == "AES-CTR")
        #expect(KeyMaterialPacket.CipherType.aesGCM.description == "AES-GCM")
    }

    @Test("KMState descriptions")
    func kmStateDescriptions() {
        for state in KeyMaterialPacket.KMState.allCases {
            #expect(!state.description.isEmpty)
        }
    }
}
