// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("Rendezvous Integration Edge Case Tests")
struct RendezvousIntegrationEdgeCaseTests {
    private let addressA: SRTPeerAddress = .ipv4(0x0A00_0001)
    private let addressB: SRTPeerAddress = .ipv4(0x0A00_0002)

    private func makeConfig(
        localSocketID: UInt32,
        passphrase: String? = nil,
        cipherType: UInt16 = 0,
        senderDelay: UInt16 = 120,
        receiverDelay: UInt16 = 120
    ) -> HandshakeConfiguration {
        HandshakeConfiguration(
            localSocketID: localSocketID,
            senderTSBPDDelay: senderDelay,
            receiverTSBPDDelay: receiverDelay,
            passphrase: passphrase,
            cipherType: cipherType
        )
    }

    private func extractSendPacket(
        from actions: [HandshakeAction]
    ) -> (HandshakePacket, [HandshakeExtensionData])? {
        for action in actions {
            if case .sendPacket(let packet, let exts) = action { return (packet, exts) }
        }
        return nil
    }

    private func extractResult(from actions: [HandshakeAction]) -> HandshakeResult? {
        for action in actions {
            if case .completed(let result) = action { return result }
        }
        return nil
    }

    @Test("Latency negotiation end-to-end")
    func latencyNegotiation() {
        var peerA = RendezvousHandshake(
            configuration: makeConfig(localSocketID: 0x2000, senderDelay: 200, receiverDelay: 200)
        )
        var peerB = RendezvousHandshake(
            configuration: makeConfig(localSocketID: 0x1000, senderDelay: 100, receiverDelay: 100)
        )

        let a1 = peerA.start()
        let b1 = peerB.start()
        guard let (waveA, _) = extractSendPacket(from: a1),
            let (waveB, _) = extractSendPacket(from: b1)
        else { return }

        let a2 = peerA.receive(handshake: waveB, extensions: [], from: addressB)
        let b2 = peerB.receive(handshake: waveA, extensions: [], from: addressA)
        guard let (concA, concExtsA) = extractSendPacket(from: a2),
            let (concB, concExtsB) = extractSendPacket(from: b2)
        else { return }

        let a3 = peerA.receive(handshake: concB, extensions: concExtsB, from: addressB)
        let resultA = extractResult(from: a3)
        #expect(resultA?.senderTSBPDDelay == 200)
        #expect(resultA?.receiverTSBPDDelay == 200)

        let b3 = peerB.receive(handshake: concA, extensions: concExtsA, from: addressA)
        let resultB = extractResult(from: b3)
        #expect(resultB?.senderTSBPDDelay == 200)
        #expect(resultB?.receiverTSBPDDelay == 200)
    }

    @Test("Result contains correct peer socket IDs")
    func resultPeerSocketIDs() {
        var peerA = RendezvousHandshake(configuration: makeConfig(localSocketID: 0xAAAA))
        var peerB = RendezvousHandshake(configuration: makeConfig(localSocketID: 0xBBBB))

        let a1 = peerA.start()
        let b1 = peerB.start()
        guard let (waveA, _) = extractSendPacket(from: a1),
            let (waveB, _) = extractSendPacket(from: b1)
        else { return }

        let a2 = peerA.receive(handshake: waveB, extensions: [], from: addressB)
        let b2 = peerB.receive(handshake: waveA, extensions: [], from: addressA)
        guard let (concA, concExtsA) = extractSendPacket(from: a2),
            let (concB, concExtsB) = extractSendPacket(from: b2)
        else { return }

        let a3 = peerA.receive(handshake: concB, extensions: concExtsB, from: addressB)
        let b3 = peerB.receive(handshake: concA, extensions: concExtsA, from: addressA)

        let resultA = extractResult(from: a3)
        let resultB = extractResult(from: b3)
        #expect(resultA?.peerSocketID == 0xBBBB)
        #expect(resultB?.peerSocketID == 0xAAAA)
    }

    @Test("KMREQ included when passphrase configured")
    func kmreqIncludedWithPassphrase() {
        var peerA = RendezvousHandshake(
            configuration: makeConfig(localSocketID: 0x2000, passphrase: "testsecret123", cipherType: 2)
        )
        _ = peerA.start()
        let actions = peerA.receive(
            handshake: HandshakePacket(version: 5, extensionField: 2, handshakeType: .waveahand, srtSocketID: 0x1000),
            extensions: [], from: addressB
        )
        guard let (_, exts) = extractSendPacket(from: actions) else {
            #expect(Bool(false), "Expected sendPacket")
            return
        }
        let hasKMREQ = exts.contains { if case .kmreq = $0 { true } else { false } }
        #expect(hasKMREQ)
    }
}
