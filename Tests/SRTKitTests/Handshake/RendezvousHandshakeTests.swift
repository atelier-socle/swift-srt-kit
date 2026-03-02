// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("RendezvousHandshake Tests")
struct RendezvousHandshakeTests {
    private let peerAddress: SRTPeerAddress = .ipv4(0x7F00_0001)

    private func makeConfig(
        localSocketID: UInt32 = 0x1000,
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

    private func makeWaveahand(socketID: UInt32 = 0x2000) -> HandshakePacket {
        HandshakePacket(
            version: 5, extensionField: 2, handshakeType: .waveahand,
            srtSocketID: socketID, synCookie: 0
        )
    }

    private func makeConclusion(
        socketID: UInt32 = 0x2000,
        senderDelay: UInt16 = 120,
        receiverDelay: UInt16 = 120
    ) -> (HandshakePacket, [HandshakeExtensionData]) {
        let packet = HandshakePacket(
            version: 5, handshakeType: .conclusion, srtSocketID: socketID
        )
        let hsreq = SRTHandshakeExtension(
            srtVersion: 0x0001_0501,
            srtFlags: [.tsbpdSender, .tsbpdReceiver],
            receiverTSBPDDelay: receiverDelay, senderTSBPDDelay: senderDelay
        )
        return (packet, [.hsreq(hsreq)])
    }

    private func makeAgreement(socketID: UInt32 = 0x2000) -> HandshakePacket {
        HandshakePacket(version: 5, handshakeType: .agreement, srtSocketID: socketID)
    }

    // MARK: - Initial state

    @Test("Initial state is idle")
    func initialStateIsIdle() {
        let rdv = RendezvousHandshake(configuration: makeConfig())
        #expect(rdv.state == .idle)
        #expect(rdv.role == nil)
    }

    // MARK: - start()

    @Test("start() returns WAVEAHAND with correct fields")
    func startReturnsWaveahand() {
        var rdv = RendezvousHandshake(configuration: makeConfig())
        let actions = rdv.start()
        #expect(actions.count == 2)
        guard case .sendPacket(let packet, let exts) = actions[0] else {
            #expect(Bool(false), "Expected sendPacket")
            return
        }
        #expect(packet.version == 5)
        #expect(packet.handshakeType == .waveahand)
        #expect(packet.synCookie == 0)
        #expect(packet.srtSocketID == 0x1000)
        #expect(packet.extensionField == 2)
        #expect(exts.isEmpty)
    }

    @Test("start() transitions to waveahandSent")
    func startTransitionsToWaveahandSent() {
        var rdv = RendezvousHandshake(configuration: makeConfig())
        _ = rdv.start()
        #expect(rdv.state == .waveahandSent)
    }

    @Test("start() twice returns error")
    func startTwiceReturnsError() {
        var rdv = RendezvousHandshake(configuration: makeConfig())
        _ = rdv.start()
        let actions = rdv.start()
        let hasError = actions.contains { if case .error = $0 { true } else { false } }
        #expect(hasError)
    }

    // MARK: - Receive WAVEAHAND

    @Test("Receive WAVEAHAND determines role: local > remote -> initiator")
    func receiveWaveahandInitiator() {
        var rdv = RendezvousHandshake(configuration: makeConfig(localSocketID: 0x2000))
        _ = rdv.start()
        _ = rdv.receive(handshake: makeWaveahand(socketID: 0x1000), extensions: [], from: peerAddress)
        #expect(rdv.role == .initiator)
    }

    @Test("Receive WAVEAHAND determines role: local < remote -> responder")
    func receiveWaveahandResponder() {
        var rdv = RendezvousHandshake(configuration: makeConfig(localSocketID: 0x1000))
        _ = rdv.start()
        _ = rdv.receive(handshake: makeWaveahand(socketID: 0x2000), extensions: [], from: peerAddress)
        #expect(rdv.role == .responder)
    }

    @Test("Receive WAVEAHAND sends CONCLUSION")
    func receiveWaveahandSendsConclusion() {
        var rdv = RendezvousHandshake(configuration: makeConfig())
        _ = rdv.start()
        let actions = rdv.receive(handshake: makeWaveahand(), extensions: [], from: peerAddress)
        #expect(rdv.state == .conclusionSent)
        guard case .sendPacket(let packet, _) = actions[0] else {
            #expect(Bool(false), "Expected sendPacket")
            return
        }
        #expect(packet.handshakeType == .conclusion)
        #expect(packet.version == 5)
    }

    @Test("Initiator's CONCLUSION includes HSREQ")
    func initiatorConclusionHasHSREQ() {
        var rdv = RendezvousHandshake(configuration: makeConfig(localSocketID: 0x2000))
        _ = rdv.start()
        let actions = rdv.receive(handshake: makeWaveahand(socketID: 0x1000), extensions: [], from: peerAddress)
        guard case .sendPacket(_, let exts) = actions[0] else {
            #expect(Bool(false), "Expected sendPacket")
            return
        }
        let hasHSREQ = exts.contains { if case .hsreq = $0 { true } else { false } }
        #expect(hasHSREQ)
    }

    @Test("Socket ID collision returns error")
    func socketIDCollision() {
        var rdv = RendezvousHandshake(configuration: makeConfig(localSocketID: 0x1000))
        _ = rdv.start()
        let actions = rdv.receive(handshake: makeWaveahand(socketID: 0x1000), extensions: [], from: peerAddress)
        let hasError = actions.contains { if case .error = $0 { true } else { false } }
        #expect(hasError)
        #expect(rdv.state == .failed)
    }

    // MARK: - Receive CONCLUSION

    @Test("Receive CONCLUSION sends AGREEMENT")
    func receiveConclusionSendsAgreement() {
        var rdv = RendezvousHandshake(configuration: makeConfig())
        _ = rdv.start()
        _ = rdv.receive(handshake: makeWaveahand(), extensions: [], from: peerAddress)
        let (pkt, exts) = makeConclusion()
        let actions = rdv.receive(handshake: pkt, extensions: exts, from: peerAddress)
        #expect(rdv.state == .agreementSent)
        guard case .sendPacket(let packet, _) = actions[0] else {
            #expect(Bool(false), "Expected sendPacket")
            return
        }
        #expect(packet.handshakeType == .agreement)
    }

    @Test("Receive CONCLUSION produces completed result")
    func receiveConclusionCompletes() {
        var rdv = RendezvousHandshake(configuration: makeConfig())
        _ = rdv.start()
        _ = rdv.receive(handshake: makeWaveahand(), extensions: [], from: peerAddress)
        let (pkt, exts) = makeConclusion()
        let actions = rdv.receive(handshake: pkt, extensions: exts, from: peerAddress)
        let hasCompleted = actions.contains { if case .completed = $0 { true } else { false } }
        #expect(hasCompleted)
    }

    @Test("Conclusion with rejection type produces error")
    func conclusionRejection() {
        var rdv = RendezvousHandshake(configuration: makeConfig())
        _ = rdv.start()
        _ = rdv.receive(handshake: makeWaveahand(), extensions: [], from: peerAddress)
        let rejPacket = HandshakePacket(
            version: 5, handshakeType: .init(rawValue: SRTRejectionReason.peer.rawValue),
            srtSocketID: 0x2000
        )
        let actions = rdv.receive(handshake: rejPacket, extensions: [], from: peerAddress)
        let hasRejection = actions.contains { action in
            if case .error(.connectionRejected(.peer)) = action { true } else { false }
        }
        #expect(hasRejection)
        #expect(rdv.state == .failed)
    }

    // MARK: - Receive AGREEMENT

    @Test("Receive AGREEMENT transitions to done")
    func receiveAgreementDone() {
        var rdv = RendezvousHandshake(configuration: makeConfig())
        _ = rdv.start()
        _ = rdv.receive(handshake: makeWaveahand(), extensions: [], from: peerAddress)
        let (pkt, exts) = makeConclusion()
        _ = rdv.receive(handshake: pkt, extensions: exts, from: peerAddress)
        let actions = rdv.receive(handshake: makeAgreement(), extensions: [], from: peerAddress)
        #expect(rdv.state == .done)
        #expect(actions.isEmpty)
    }

    // MARK: - Fast path

    @Test("AGREEMENT in conclusionSent (fast path) completes")
    func fastPathAgreementInConclusionSent() {
        var rdv = RendezvousHandshake(configuration: makeConfig())
        _ = rdv.start()
        _ = rdv.receive(handshake: makeWaveahand(), extensions: [], from: peerAddress)
        let actions = rdv.receive(handshake: makeAgreement(), extensions: [], from: peerAddress)
        #expect(rdv.state == .done)
        let hasCompleted = actions.contains { if case .completed = $0 { true } else { false } }
        #expect(hasCompleted)
    }
}
