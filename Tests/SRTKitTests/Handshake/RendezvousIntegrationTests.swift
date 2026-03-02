// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("Rendezvous Integration Tests")
struct RendezvousIntegrationTests {
    private let addressA: SRTPeerAddress = .ipv4(0x0A00_0001)
    private let addressB: SRTPeerAddress = .ipv4(0x0A00_0002)

    private func makeConfig(
        localSocketID: UInt32,
        streamID: String? = nil,
        passphrase: String? = nil,
        cipherType: UInt16 = 0,
        senderDelay: UInt16 = 120,
        receiverDelay: UInt16 = 120
    ) -> HandshakeConfiguration {
        HandshakeConfiguration(
            localSocketID: localSocketID,
            senderTSBPDDelay: senderDelay,
            receiverTSBPDDelay: receiverDelay,
            streamID: streamID,
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

    // MARK: - Happy path

    @Test("Full rendezvous handshake: both peers reach done")
    func fullHandshakeHappyPath() {
        var peerA = RendezvousHandshake(configuration: makeConfig(localSocketID: 0x2000))
        var peerB = RendezvousHandshake(configuration: makeConfig(localSocketID: 0x1000))

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

        #expect(peerA.role == .initiator)
        #expect(peerB.role == .responder)

        let a3 = peerA.receive(handshake: concB, extensions: concExtsB, from: addressB)
        let b3 = peerB.receive(handshake: concA, extensions: concExtsA, from: addressA)
        guard let (agrA, _) = extractSendPacket(from: a3),
            let (agrB, _) = extractSendPacket(from: b3)
        else { return }

        let resultA = extractResult(from: a3)
        let resultB = extractResult(from: b3)
        #expect(resultA != nil)
        #expect(resultB != nil)

        _ = peerA.receive(handshake: agrB, extensions: [], from: addressB)
        _ = peerB.receive(handshake: agrA, extensions: [], from: addressA)
        #expect(peerA.state == .done)
        #expect(peerB.state == .done)
        #expect(resultA?.peerSocketID == 0x1000)
        #expect(resultB?.peerSocketID == 0x2000)
    }

    @Test("Peer A initiator (higher ID), Peer B responder")
    func peerAInitiator() {
        var peerA = RendezvousHandshake(configuration: makeConfig(localSocketID: 0x5000))
        var peerB = RendezvousHandshake(configuration: makeConfig(localSocketID: 0x3000))
        _ = peerA.start()
        _ = peerB.start()
        _ = peerA.receive(
            handshake: HandshakePacket(version: 5, extensionField: 2, handshakeType: .waveahand, srtSocketID: 0x3000),
            extensions: [], from: addressB
        )
        _ = peerB.receive(
            handshake: HandshakePacket(version: 5, extensionField: 2, handshakeType: .waveahand, srtSocketID: 0x5000),
            extensions: [], from: addressA
        )
        #expect(peerA.role == .initiator)
        #expect(peerB.role == .responder)
    }

    @Test("Peer B initiator (higher ID), Peer A responder")
    func peerBInitiator() {
        var peerA = RendezvousHandshake(configuration: makeConfig(localSocketID: 0x1000))
        var peerB = RendezvousHandshake(configuration: makeConfig(localSocketID: 0x9000))
        _ = peerA.start()
        _ = peerB.start()
        _ = peerA.receive(
            handshake: HandshakePacket(version: 5, extensionField: 2, handshakeType: .waveahand, srtSocketID: 0x9000),
            extensions: [], from: addressB
        )
        _ = peerB.receive(
            handshake: HandshakePacket(version: 5, extensionField: 2, handshakeType: .waveahand, srtSocketID: 0x1000),
            extensions: [], from: addressA
        )
        #expect(peerA.role == .responder)
        #expect(peerB.role == .initiator)
    }

    @Test("Both with StreamID")
    func bothWithStreamID() {
        var peerA = RendezvousHandshake(
            configuration: makeConfig(localSocketID: 0x2000, streamID: "live/test")
        )
        _ = peerA.start()
        let actions = peerA.receive(
            handshake: HandshakePacket(version: 5, extensionField: 2, handshakeType: .waveahand, srtSocketID: 0x1000),
            extensions: [], from: addressB
        )
        guard let (_, exts) = extractSendPacket(from: actions) else { return }
        let hasSID = exts.contains { if case .streamID("live/test") = $0 { true } else { false } }
        #expect(hasSID)
    }

    @Test("One peer times out")
    func onePeerTimesOut() {
        var peerA = RendezvousHandshake(configuration: makeConfig(localSocketID: 0x2000))
        _ = peerA.start()
        let action = peerA.timeout()
        if case .error(.handshakeTimeout) = action {
            #expect(Bool(true))
        } else {
            #expect(Bool(false), "Expected handshakeTimeout")
        }
        #expect(peerA.state == .failed)
    }

    @Test("Socket ID collision: both fail")
    func socketIDCollisionBothFail() {
        var peerA = RendezvousHandshake(configuration: makeConfig(localSocketID: 0x1000))
        var peerB = RendezvousHandshake(configuration: makeConfig(localSocketID: 0x1000))
        _ = peerA.start()
        _ = peerB.start()
        let actA = peerA.receive(
            handshake: HandshakePacket(version: 5, extensionField: 2, handshakeType: .waveahand, srtSocketID: 0x1000),
            extensions: [], from: addressB
        )
        let actB = peerB.receive(
            handshake: HandshakePacket(version: 5, extensionField: 2, handshakeType: .waveahand, srtSocketID: 0x1000),
            extensions: [], from: addressA
        )
        let aFailed = actA.contains { if case .error = $0 { true } else { false } }
        let bFailed = actB.contains { if case .error = $0 { true } else { false } }
        #expect(aFailed)
        #expect(bFailed)
        #expect(peerA.state == .failed)
        #expect(peerB.state == .failed)
    }
}
