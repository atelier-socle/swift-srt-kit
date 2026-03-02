// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("CallerHandshake Edge Case Tests")
struct CallerHandshakeEdgeCaseTests {
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

    // MARK: - Rejection

    @Test("Conclusion with REJ_PEER produces connectionRejected")
    func rejectionPeer() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        _ = caller.receive(
            handshake: makeInductionResponse(),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )
        let rejPacket = HandshakePacket(
            version: 5,
            handshakeType: .init(rawValue: SRTRejectionReason.peer.rawValue),
            srtSocketID: 0x5678
        )
        let actions = caller.receive(
            handshake: rejPacket, extensions: [], from: .ipv4(0x7F00_0001)
        )

        let hasRejection = actions.contains { action in
            if case .error(.connectionRejected(.peer)) = action { return true }
            return false
        }
        #expect(hasRejection)
        #expect(caller.state == .failed)
    }

    @Test("Conclusion with REJ_BADSECRET produces correct reason")
    func rejectionBadSecret() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        _ = caller.receive(
            handshake: makeInductionResponse(),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )
        let rejPacket = HandshakePacket(
            version: 5,
            handshakeType: .init(rawValue: SRTRejectionReason.badSecret.rawValue),
            srtSocketID: 0x5678
        )
        let actions = caller.receive(
            handshake: rejPacket, extensions: [], from: .ipv4(0x7F00_0001)
        )

        let hasRejection = actions.contains { action in
            if case .error(.connectionRejected(.badSecret)) = action { return true }
            return false
        }
        #expect(hasRejection)
    }

    // MARK: - Version mismatch

    @Test("Induction response with version != 5 produces error")
    func versionMismatch() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        let badResponse = HandshakePacket(
            version: 4,
            handshakeType: .induction,
            srtSocketID: 0x5678,
            synCookie: 0xABCD
        )
        let actions = caller.receive(
            handshake: badResponse, extensions: [], from: .ipv4(0x7F00_0001)
        )

        let hasVersionError = actions.contains { action in
            if case .error(.versionMismatch) = action { return true }
            return false
        }
        #expect(hasVersionError)
        #expect(caller.state == .failed)
    }

    @Test("Wrong handshake type in induction response produces error")
    func wrongTypeInInductionResponse() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        let badResponse = HandshakePacket(
            version: 5,
            handshakeType: .conclusion,
            srtSocketID: 0x5678
        )
        let actions = caller.receive(
            handshake: badResponse, extensions: [], from: .ipv4(0x7F00_0001)
        )

        let hasError = actions.contains { action in
            if case .error = action { return true }
            return false
        }
        #expect(hasError)
        #expect(caller.state == .failed)
    }

    // MARK: - Wrong state

    @Test("Receive in idle state returns error")
    func receiveInIdleState() {
        var caller = CallerHandshake(configuration: makeConfig())
        let actions = caller.receive(
            handshake: makeInductionResponse(),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )

        let hasError = actions.contains { action in
            if case .error = action { return true }
            return false
        }
        #expect(hasError)
    }

    @Test("Receive in done state returns error")
    func receiveInDoneState() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        _ = caller.receive(
            handshake: makeInductionResponse(),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )
        let (packet, exts) = makeConclusionResponse()
        _ = caller.receive(handshake: packet, extensions: exts, from: .ipv4(0x7F00_0001))

        let actions = caller.receive(
            handshake: makeInductionResponse(),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )
        let hasError = actions.contains { action in
            if case .error = action { return true }
            return false
        }
        #expect(hasError)
    }

    // MARK: - Timeout

    @Test("Timeout in inductionSent produces handshakeTimeout")
    func timeoutInInductionSent() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        let action = caller.timeout()

        if case .error(.handshakeTimeout) = action {
            #expect(Bool(true))
        } else {
            #expect(Bool(false), "Expected handshakeTimeout")
        }
        #expect(caller.state == .failed)
    }

    @Test("Timeout in conclusionSent produces handshakeTimeout")
    func timeoutInConclusionSent() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        _ = caller.receive(
            handshake: makeInductionResponse(),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )
        let action = caller.timeout()

        if case .error(.handshakeTimeout) = action {
            #expect(Bool(true))
        } else {
            #expect(Bool(false), "Expected handshakeTimeout")
        }
        #expect(caller.state == .failed)
    }

    @Test("Timeout in idle state produces error")
    func timeoutInIdleState() {
        var caller = CallerHandshake(configuration: makeConfig())
        let action = caller.timeout()

        if case .error = action {
            #expect(Bool(true))
        } else {
            #expect(Bool(false), "Expected error action")
        }
    }

    // MARK: - Idempotent failure

    @Test("After failure, further receive() calls return error")
    func idempotentFailure() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        _ = caller.timeout()
        #expect(caller.state == .failed)

        let actions = caller.receive(
            handshake: makeInductionResponse(),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )

        let hasError = actions.contains { action in
            if case .error = action { return true }
            return false
        }
        #expect(hasError)
    }

    // MARK: - Happy path end-to-end

    @Test("Happy path: start -> induction -> conclusion -> done")
    func happyPath() {
        var caller = CallerHandshake(configuration: makeConfig())

        let startActions = caller.start()
        #expect(caller.state == .inductionSent)
        #expect(startActions.count == 2)

        let inductionActions = caller.receive(
            handshake: makeInductionResponse(cookie: 0x1111, peerSocketID: 0x2222),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )
        #expect(caller.state == .conclusionSent)
        #expect(inductionActions.count == 2)

        let (conclusionPacket, conclusionExts) = makeConclusionResponse(peerSocketID: 0x2222)
        let conclusionActions = caller.receive(
            handshake: conclusionPacket,
            extensions: conclusionExts,
            from: .ipv4(0x7F00_0001)
        )
        #expect(caller.state == .done)

        guard
            case .completed(let result) = conclusionActions.first(where: { action in
                if case .completed = action { return true }
                return false
            })
        else {
            #expect(Bool(false), "Expected completed action")
            return
        }
        #expect(result.peerSocketID == 0x2222)
    }

    @Test("Conclusion version 5 is accepted")
    func conclusionVersion5() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        _ = caller.receive(
            handshake: makeInductionResponse(),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )
        let packet = HandshakePacket(version: 5, handshakeType: .conclusion, srtSocketID: 0x5678)
        let hsrsp = SRTHandshakeExtension(
            srtVersion: 0x0001_0501,
            srtFlags: [.tsbpdSender, .tsbpdReceiver],
            receiverTSBPDDelay: 120,
            senderTSBPDDelay: 120
        )
        let actions = caller.receive(
            handshake: packet, extensions: [.hsrsp(hsrsp)], from: .ipv4(0x7F00_0001)
        )
        #expect(caller.state == .done)

        let hasCompleted = actions.contains { action in
            if case .completed = action { return true }
            return false
        }
        #expect(hasCompleted)
    }

    @Test("Initial state is idle")
    func initialStateIsIdle() {
        let caller = CallerHandshake(configuration: makeConfig())
        #expect(caller.state == .idle)
    }
}
