// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("Packet Showcase")
struct PacketShowcaseTests {
    // MARK: - Data Packets

    @Test("SRTDataPacket creation with all positions")
    func dataPacketPositions() {
        let positions: [SRTDataPacket.Position] = [
            .single, .first, .middle, .last
        ]
        for position in positions {
            let packet = SRTDataPacket(
                sequenceNumber: SequenceNumber(42),
                position: position,
                payload: [0x47, 0x00, 0x11, 0x00])
            #expect(packet.position == position)
            #expect(packet.payload.count == 4)
            #expect(packet.sequenceNumber == SequenceNumber(42))
        }
    }

    @Test("SRTDataPacket encryption key variants")
    func dataPacketEncryptionKeys() {
        let keys: [SRTDataPacket.EncryptionKey] = [
            .none, .even, .odd, .controlOnly
        ]
        for key in keys {
            let packet = SRTDataPacket(
                sequenceNumber: SequenceNumber(1),
                encryptionKey: key)
            #expect(packet.encryptionKey == key)
        }
    }

    @Test("SRTDataPacket retransmission flag and message number")
    func dataPacketRetransmission() {
        let packet = SRTDataPacket(
            sequenceNumber: SequenceNumber(100),
            retransmitted: true,
            messageNumber: 0x03FF_FFFF,
            timestamp: 1_000_000,
            destinationSocketID: 0xDEAD)
        #expect(packet.retransmitted)
        #expect(packet.messageNumber == SRTDataPacket.maxMessageNumber)
        #expect(packet.timestamp == 1_000_000)
        #expect(packet.destinationSocketID == 0xDEAD)
    }

    // MARK: - Control Packets

    @Test("SRTControlPacket with all control types")
    func controlPacketTypes() {
        let types: [ControlType] = [
            .handshake, .keepalive, .ack, .nak,
            .congestion, .shutdown, .ackack,
            .dropreq, .peererror, .userDefined
        ]
        for controlType in types {
            let packet = SRTControlPacket(
                controlType: controlType,
                timestamp: 5000,
                destinationSocketID: 42)
            #expect(packet.controlType == controlType)
        }
        #expect(ControlType.allCases.count == types.count)
    }

    // MARK: - ACK Packets

    @Test("ACKPacket light vs full")
    func ackPacketLightAndFull() {
        let light = ACKPacket(
            acknowledgementNumber: SequenceNumber(500))
        #expect(light.isLightACK)
        #expect(light.rtt == nil)

        let full = ACKPacket(
            acknowledgementNumber: SequenceNumber(500),
            rtt: 20_000,
            rttVariance: 5_000,
            availableBufferSize: 8192,
            packetsReceivingRate: 1000,
            estimatedLinkCapacity: 50_000,
            receivingRate: 10_000_000)
        #expect(!full.isLightACK)
        #expect(full.rtt == 20_000)
        #expect(full.estimatedLinkCapacity == 50_000)
    }

    @Test("ACKPacket encode/decode roundtrip")
    func ackPacketRoundtrip() throws {
        let original = ACKPacket(
            acknowledgementNumber: SequenceNumber(1234),
            rtt: 15_000,
            rttVariance: 3_000,
            availableBufferSize: 4096,
            packetsReceivingRate: 500,
            estimatedLinkCapacity: 25_000,
            receivingRate: 5_000_000)

        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        original.encode(into: &buffer)

        let cifLength = buffer.readableBytes
        let decoded = try ACKPacket.decode(
            from: &buffer, cifLength: cifLength)
        #expect(decoded.acknowledgementNumber == original.acknowledgementNumber)
        #expect(decoded.rtt == original.rtt)
        #expect(decoded.rttVariance == original.rttVariance)
    }

    // MARK: - NAK Packets

    @Test("NAKPacket single and range loss entries")
    func nakPacketLossEntries() {
        let nak = NAKPacket(lossEntries: [
            .single(SequenceNumber(10)),
            .range(
                from: SequenceNumber(20), to: SequenceNumber(25)),
            .single(SequenceNumber(30))
        ])

        let lost = nak.lostSequenceNumbers
        #expect(lost.contains(SequenceNumber(10)))
        #expect(lost.contains(SequenceNumber(22)))
        #expect(lost.contains(SequenceNumber(30)))
    }

    // MARK: - Handshake Packets

    @Test("HandshakePacket all handshake types")
    func handshakePacketTypes() {
        let types: [HandshakePacket.HandshakeType] = [
            .induction, .conclusion, .waveahand,
            .done, .agreement
        ]
        for hsType in types {
            let packet = HandshakePacket(
                version: 5,
                handshakeType: hsType,
                srtSocketID: 0xABCD)
            #expect(packet.handshakeType == hsType)
            #expect(packet.version == 5)
            #expect(packet.srtSocketID == 0xABCD)
        }
    }

    @Test("HandshakePacket encode/decode roundtrip")
    func handshakePacketRoundtrip() throws {
        let original = HandshakePacket(
            version: 5,
            encryptionField: 2,
            extensionField: 0x0001,
            initialPacketSequenceNumber: SequenceNumber(100),
            maxTransmissionUnitSize: 1500,
            maxFlowWindowSize: 8192,
            handshakeType: .induction,
            srtSocketID: 0x1234,
            synCookie: 0xDEAD_BEEF,
            peerIPAddress: .ipv4(0x7F00_0001))

        var buffer = ByteBufferAllocator().buffer(capacity: 64)
        original.encode(into: &buffer)

        let decoded = try HandshakePacket.decode(from: &buffer)
        #expect(decoded.version == original.version)
        #expect(decoded.handshakeType == original.handshakeType)
        #expect(decoded.srtSocketID == original.srtSocketID)
        #expect(decoded.synCookie == original.synCookie)
    }

    // MARK: - Key Material

    @Test("KeyMaterialPacket cipher types")
    func keyMaterialCipherTypes() {
        for cipher in KeyMaterialPacket.CipherType.allCases {
            let packet = KeyMaterialPacket(
                cipher: cipher,
                salt: Array(repeating: 0xAA, count: 16),
                keyLength: 16,
                wrappedKeys: Array(repeating: 0xBB, count: 24))
            #expect(packet.cipher == cipher)
            #expect(packet.sign == KeyMaterialPacket.expectedSign)
        }
    }

    // MARK: - Peer Address

    @Test("SRTPeerAddress IPv4 and IPv6")
    func peerAddressVariants() {
        let ipv4 = SRTPeerAddress.ipv4(0x7F00_0001)
        let ipv6 = SRTPeerAddress.ipv6(0, 1)

        #expect(ipv4 != ipv6)
        #expect(SRTPeerAddress.encodedSize == 16)
    }
}
