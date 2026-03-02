// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("RendezvousHandshake Edge Case Tests")
struct RendezvousHandshakeEdgeCaseTests {
    private let peerAddress: SRTPeerAddress = .ipv4(0x7F00_0001)

    private func makeConfig(localSocketID: UInt32 = 0x1000) -> HandshakeConfiguration {
        HandshakeConfiguration(localSocketID: localSocketID)
    }

    private func makeWaveahand(socketID: UInt32 = 0x2000) -> HandshakePacket {
        HandshakePacket(
            version: 5, extensionField: 2, handshakeType: .waveahand,
            srtSocketID: socketID, synCookie: 0
        )
    }

    private func makeConclusion(socketID: UInt32 = 0x2000) -> (HandshakePacket, [HandshakeExtensionData]) {
        let packet = HandshakePacket(version: 5, handshakeType: .conclusion, srtSocketID: socketID)
        let hsreq = SRTHandshakeExtension(
            srtVersion: 0x0001_0501,
            srtFlags: [.tsbpdSender, .tsbpdReceiver],
            receiverTSBPDDelay: 120, senderTSBPDDelay: 120
        )
        return (packet, [.hsreq(hsreq)])
    }

    private func makeAgreement(socketID: UInt32 = 0x2000) -> HandshakePacket {
        HandshakePacket(version: 5, handshakeType: .agreement, srtSocketID: socketID)
    }

    // MARK: - Wrong state

    @Test("Receive in idle returns error")
    func receiveInIdleReturnsError() {
        var rdv = RendezvousHandshake(configuration: makeConfig())
        let actions = rdv.receive(handshake: makeWaveahand(), extensions: [], from: peerAddress)
        let hasError = actions.contains { if case .error = $0 { true } else { false } }
        #expect(hasError)
    }

    @Test("Receive in done returns error")
    func receiveInDoneReturnsError() {
        var rdv = RendezvousHandshake(configuration: makeConfig())
        _ = rdv.start()
        _ = rdv.receive(handshake: makeWaveahand(), extensions: [], from: peerAddress)
        _ = rdv.receive(handshake: makeAgreement(), extensions: [], from: peerAddress)
        #expect(rdv.state == .done)
        let actions = rdv.receive(handshake: makeWaveahand(), extensions: [], from: peerAddress)
        let hasError = actions.contains { if case .error = $0 { true } else { false } }
        #expect(hasError)
    }

    @Test("Receive in failed returns error")
    func receiveInFailedReturnsError() {
        var rdv = RendezvousHandshake(configuration: makeConfig())
        _ = rdv.start()
        _ = rdv.timeout()
        #expect(rdv.state == .failed)
        let actions = rdv.receive(handshake: makeWaveahand(), extensions: [], from: peerAddress)
        let hasError = actions.contains { if case .error = $0 { true } else { false } }
        #expect(hasError)
    }

    // MARK: - Timeout

    @Test("Timeout in waveahandSent -> failed")
    func timeoutInWaveahandSent() {
        var rdv = RendezvousHandshake(configuration: makeConfig())
        _ = rdv.start()
        let action = rdv.timeout()
        if case .error(.handshakeTimeout) = action {
            #expect(Bool(true))
        } else {
            #expect(Bool(false), "Expected handshakeTimeout")
        }
        #expect(rdv.state == .failed)
    }

    @Test("Timeout in conclusionSent -> failed")
    func timeoutInConclusionSent() {
        var rdv = RendezvousHandshake(configuration: makeConfig())
        _ = rdv.start()
        _ = rdv.receive(handshake: makeWaveahand(), extensions: [], from: peerAddress)
        let action = rdv.timeout()
        if case .error(.handshakeTimeout) = action {
            #expect(Bool(true))
        } else {
            #expect(Bool(false), "Expected handshakeTimeout")
        }
        #expect(rdv.state == .failed)
    }

    @Test("Timeout in agreementSent -> failed")
    func timeoutInAgreementSent() {
        var rdv = RendezvousHandshake(configuration: makeConfig())
        _ = rdv.start()
        _ = rdv.receive(handshake: makeWaveahand(), extensions: [], from: peerAddress)
        let (pkt, exts) = makeConclusion()
        _ = rdv.receive(handshake: pkt, extensions: exts, from: peerAddress)
        let action = rdv.timeout()
        if case .error(.handshakeTimeout) = action {
            #expect(Bool(true))
        } else {
            #expect(Bool(false), "Expected handshakeTimeout")
        }
        #expect(rdv.state == .failed)
    }

    @Test("Timeout in idle returns error")
    func timeoutInIdle() {
        var rdv = RendezvousHandshake(configuration: makeConfig())
        let action = rdv.timeout()
        if case .error = action {
            #expect(Bool(true))
        } else {
            #expect(Bool(false), "Expected error")
        }
    }

    // MARK: - Wrong handshake type

    @Test("Wrong type in waveahandSent returns error")
    func wrongTypeInWaveahandSent() {
        var rdv = RendezvousHandshake(configuration: makeConfig())
        _ = rdv.start()
        let badPacket = HandshakePacket(version: 5, handshakeType: .conclusion, srtSocketID: 0x2000)
        let actions = rdv.receive(handshake: badPacket, extensions: [], from: peerAddress)
        let hasError = actions.contains { if case .error = $0 { true } else { false } }
        #expect(hasError)
        #expect(rdv.state == .failed)
    }

    @Test("Wrong type in agreementSent returns error")
    func wrongTypeInAgreementSent() {
        var rdv = RendezvousHandshake(configuration: makeConfig())
        _ = rdv.start()
        _ = rdv.receive(handshake: makeWaveahand(), extensions: [], from: peerAddress)
        let (pkt, exts) = makeConclusion()
        _ = rdv.receive(handshake: pkt, extensions: exts, from: peerAddress)
        let badPacket = HandshakePacket(version: 5, handshakeType: .waveahand, srtSocketID: 0x2000)
        let actions = rdv.receive(handshake: badPacket, extensions: [], from: peerAddress)
        let hasError = actions.contains { if case .error = $0 { true } else { false } }
        #expect(hasError)
        #expect(rdv.state == .failed)
    }
}
