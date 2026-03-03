// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("CallerHandshake Tests")
struct CallerHandshakeTests {
    private func makeConfig(
        localSocketID: UInt32 = 0x1234,
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

    private func makeInductionResponse(
        cookie: UInt32 = 0xABCD,
        peerSocketID: UInt32 = 0x5678,
        encryptionField: UInt16 = 0
    ) -> HandshakePacket {
        HandshakePacket(
            version: 5,
            encryptionField: encryptionField,
            extensionField: 0x4A17,
            handshakeType: .induction,
            srtSocketID: peerSocketID,
            synCookie: cookie
        )
    }

    private func makeConclusionResponse(
        peerSocketID: UInt32 = 0x5678,
        senderDelay: UInt16 = 200,
        receiverDelay: UInt16 = 200
    ) -> (HandshakePacket, [HandshakeExtensionData]) {
        let packet = HandshakePacket(
            version: 5,
            handshakeType: .conclusion,
            srtSocketID: peerSocketID
        )
        let hsrsp = SRTHandshakeExtension(
            srtVersion: 0x0001_0501,
            srtFlags: [.tsbpdSender, .tsbpdReceiver, .tlpktDrop, .periodicNAK, .rexmitFlag],
            receiverTSBPDDelay: receiverDelay,
            senderTSBPDDelay: senderDelay
        )
        return (packet, [.hsrsp(hsrsp)])
    }

    // MARK: - start()

    @Test("start() returns induction packet with correct fields")
    func startReturnsInductionPacket() {
        var caller = CallerHandshake(configuration: makeConfig())
        let actions = caller.start()

        let sendAction = actions.first { action in
            if case .sendPacket = action { return true }
            return false
        }
        guard case .sendPacket(let packet, let extensions) = sendAction else {
            #expect(Bool(false), "Expected sendPacket action")
            return
        }
        #expect(packet.version == 4)
        #expect(packet.synCookie == 0)
        #expect(packet.handshakeType == .induction)
        #expect(packet.extensionField == 2)
        #expect(packet.srtSocketID == 0x1234)
        #expect(extensions.isEmpty)
    }

    @Test("start() transitions to inductionSent")
    func startTransitionsToInductionSent() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        #expect(caller.state == .inductionSent)
    }

    @Test("start() returns waitForResponse action")
    func startReturnsWaitAction() {
        var caller = CallerHandshake(configuration: makeConfig())
        let actions = caller.start()

        let hasWait = actions.contains { action in
            if case .waitForResponse = action { return true }
            return false
        }
        #expect(hasWait)
    }

    @Test("start() twice returns error")
    func startTwiceReturnsError() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        let actions = caller.start()

        let hasError = actions.contains { action in
            if case .error = action { return true }
            return false
        }
        #expect(hasError)
    }

    // MARK: - Induction response

    @Test("Receive valid induction response transitions to conclusionSent")
    func receiveInductionTransitions() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        _ = caller.receive(
            handshake: makeInductionResponse(),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )
        #expect(caller.state == .conclusionSent)
    }

    @Test("Conclusion packet includes cookie from induction response")
    func conclusionIncludesCookie() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        let actions = caller.receive(
            handshake: makeInductionResponse(cookie: 0xDEAD_BEEF),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )

        let sendAction = actions.first { action in
            if case .sendPacket = action { return true }
            return false
        }
        guard case .sendPacket(let packet, _) = sendAction else {
            #expect(Bool(false), "Expected sendPacket action")
            return
        }
        #expect(packet.synCookie == 0xDEAD_BEEF)
    }

    @Test("Conclusion packet includes HSREQ with configured version/flags/latency")
    func conclusionIncludesHSREQ() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        let actions = caller.receive(
            handshake: makeInductionResponse(),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )

        let sendAction = actions.first { action in
            if case .sendPacket = action { return true }
            return false
        }
        guard case .sendPacket(_, let extensions) = sendAction else {
            #expect(Bool(false), "Expected sendPacket action")
            return
        }

        let hasHSREQ = extensions.contains { ext in
            if case .hsreq = ext { return true }
            return false
        }
        #expect(hasHSREQ)
    }

    @Test("Conclusion packet includes SID when configured")
    func conclusionIncludesSID() {
        var caller = CallerHandshake(configuration: makeConfig(streamID: "live/test"))
        _ = caller.start()
        let actions = caller.receive(
            handshake: makeInductionResponse(),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )

        guard
            case .sendPacket(_, let extensions) = actions.first(where: { action in
                if case .sendPacket = action { return true }
                return false
            })
        else {
            #expect(Bool(false), "Expected sendPacket action")
            return
        }

        let hasSID = extensions.contains { ext in
            if case .streamID("live/test") = ext { return true }
            return false
        }
        #expect(hasSID)
    }

    @Test("Conclusion packet includes KMREQ when passphrase configured")
    func conclusionIncludesKMREQ() {
        var caller = CallerHandshake(
            configuration: makeConfig(passphrase: "testsecret123", cipherType: 2)
        )
        _ = caller.start()
        let actions = caller.receive(
            handshake: makeInductionResponse(),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )

        guard
            case .sendPacket(_, let extensions) = actions.first(where: { action in
                if case .sendPacket = action { return true }
                return false
            })
        else {
            #expect(Bool(false), "Expected sendPacket action")
            return
        }

        let hasKMREQ = extensions.contains { ext in
            if case .kmreq = ext { return true }
            return false
        }
        #expect(hasKMREQ)
    }

    @Test("No KMREQ when passphrase is nil")
    func noKMREQWhenNoPassphrase() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        let actions = caller.receive(
            handshake: makeInductionResponse(),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )

        guard
            case .sendPacket(_, let extensions) = actions.first(where: { action in
                if case .sendPacket = action { return true }
                return false
            })
        else {
            #expect(Bool(false), "Expected sendPacket action")
            return
        }

        let hasKMREQ = extensions.contains { ext in
            if case .kmreq = ext { return true }
            return false
        }
        #expect(!hasKMREQ)
    }

    // MARK: - Conclusion response

    @Test("Receive valid conclusion response transitions to done")
    func receiveConclusionTransitionsToDone() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        _ = caller.receive(
            handshake: makeInductionResponse(),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )
        let (packet, exts) = makeConclusionResponse()
        _ = caller.receive(handshake: packet, extensions: exts, from: .ipv4(0x7F00_0001))
        #expect(caller.state == .done)
    }

    @Test("Conclusion response produces completed action with correct result")
    func conclusionResponseCompletedResult() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        _ = caller.receive(
            handshake: makeInductionResponse(),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )
        let (packet, exts) = makeConclusionResponse(peerSocketID: 0x9999)
        let actions = caller.receive(
            handshake: packet, extensions: exts, from: .ipv4(0x7F00_0001)
        )

        let completed = actions.first { action in
            if case .completed = action { return true }
            return false
        }
        guard case .completed(let result) = completed else {
            #expect(Bool(false), "Expected completed action")
            return
        }
        #expect(result.peerSocketID == 0x9999)
    }

    @Test("Latency negotiated correctly from HSRSP")
    func latencyNegotiatedFromHSRSP() {
        var caller = CallerHandshake(
            configuration: makeConfig(senderDelay: 100, receiverDelay: 100)
        )
        _ = caller.start()
        _ = caller.receive(
            handshake: makeInductionResponse(),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )
        let (packet, exts) = makeConclusionResponse(senderDelay: 200, receiverDelay: 300)
        let actions = caller.receive(
            handshake: packet, extensions: exts, from: .ipv4(0x7F00_0001)
        )

        guard
            case .completed(let result) = actions.first(where: { action in
                if case .completed = action { return true }
                return false
            })
        else {
            #expect(Bool(false), "Expected completed action")
            return
        }

        // senderDelay = max(local_sender=100, remote_receiver=300) = 300
        #expect(result.senderTSBPDDelay == 300)
        // receiverDelay = max(local_receiver=100, remote_sender=200) = 200
        #expect(result.receiverTSBPDDelay == 200)
    }

}
