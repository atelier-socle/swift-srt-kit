// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("ListenerHandshake Tests")
struct ListenerHandshakeTests {
    private let cookieSecret: [UInt8] = [10, 20, 30, 40, 50, 60, 70, 80]
    private let peerAddress: SRTPeerAddress = .ipv4(0x7F00_0001)

    private func makeListenerConfig(
        localSocketID: UInt32 = 0xAAAA,
        cipherType: UInt16 = 0,
        senderDelay: UInt16 = 120,
        receiverDelay: UInt16 = 120
    ) -> HandshakeConfiguration {
        HandshakeConfiguration(
            localSocketID: localSocketID,
            senderTSBPDDelay: senderDelay,
            receiverTSBPDDelay: receiverDelay,
            cipherType: cipherType
        )
    }

    private func makeInductionRequest(
        callerSocketID: UInt32 = 0xBBBB
    ) -> HandshakePacket {
        HandshakePacket(
            version: 4,
            extensionField: 2,
            handshakeType: .induction,
            srtSocketID: callerSocketID
        )
    }

    private func makeConclusionRequest(
        cookie: UInt32,
        callerSocketID: UInt32 = 0xBBBB,
        encryptionField: UInt16 = 0,
        senderDelay: UInt16 = 120,
        receiverDelay: UInt16 = 120,
        streamID: String? = nil
    ) -> (HandshakePacket, [HandshakeExtensionData]) {
        let packet = HandshakePacket(
            version: 5,
            encryptionField: encryptionField,
            extensionField: HandshakePacket.ExtensionFlags([.hsreq]).rawValue,
            handshakeType: .conclusion,
            srtSocketID: callerSocketID,
            synCookie: cookie,
            peerIPAddress: peerAddress
        )
        let hsreq = SRTHandshakeExtension(
            srtVersion: 0x0001_0501,
            srtFlags: [.tsbpdSender, .tsbpdReceiver, .tlpktDrop, .periodicNAK, .rexmitFlag],
            receiverTSBPDDelay: receiverDelay,
            senderTSBPDDelay: senderDelay
        )
        var extensions: [HandshakeExtensionData] = [.hsreq(hsreq)]
        if let sid = streamID {
            extensions.append(.streamID(sid))
        }
        return (packet, extensions)
    }

    private func generateCookie(timeBucket: UInt32 = 0) -> UInt32 {
        CookieGenerator.generate(
            peerAddress: peerAddress, peerPort: 0, secret: cookieSecret, timeBucket: timeBucket
        )
    }

    // MARK: - Induction

    @Test("Induction response has version 5")
    func inductionResponseVersion5() {
        let listener = ListenerHandshake(configuration: makeListenerConfig())
        let action = listener.processInduction(
            handshake: makeInductionRequest(),
            from: peerAddress,
            cookieSecret: cookieSecret
        )
        guard case .sendPacket(let packet, _) = action else {
            #expect(Bool(false), "Expected sendPacket action")
            return
        }
        #expect(packet.version == 5)
    }

    @Test("Induction response has cookie")
    func inductionResponseHasCookie() {
        let listener = ListenerHandshake(configuration: makeListenerConfig())
        let action = listener.processInduction(
            handshake: makeInductionRequest(),
            from: peerAddress,
            cookieSecret: cookieSecret
        )
        guard case .sendPacket(let packet, _) = action else {
            #expect(Bool(false), "Expected sendPacket action")
            return
        }
        #expect(packet.synCookie != 0)
    }

    @Test("Induction response has listener socket ID")
    func inductionResponseHasListenerSocketID() {
        let listener = ListenerHandshake(configuration: makeListenerConfig(localSocketID: 0xFFFF))
        let action = listener.processInduction(
            handshake: makeInductionRequest(),
            from: peerAddress,
            cookieSecret: cookieSecret
        )
        guard case .sendPacket(let packet, _) = action else {
            #expect(Bool(false), "Expected sendPacket action")
            return
        }
        #expect(packet.srtSocketID == 0xFFFF)
    }

    @Test("Induction response has encryption field from config")
    func inductionResponseEncryptionField() {
        let listener = ListenerHandshake(configuration: makeListenerConfig(cipherType: 2))
        let action = listener.processInduction(
            handshake: makeInductionRequest(),
            from: peerAddress,
            cookieSecret: cookieSecret
        )
        guard case .sendPacket(let packet, _) = action else {
            #expect(Bool(false), "Expected sendPacket action")
            return
        }
        #expect(packet.encryptionField == 2)
    }

    @Test("Induction processing is stateless (state unchanged)")
    func inductionIsStateless() {
        let listener = ListenerHandshake(configuration: makeListenerConfig())
        _ = listener.processInduction(
            handshake: makeInductionRequest(),
            from: peerAddress,
            cookieSecret: cookieSecret
        )
        #expect(listener.state == .idle)
    }

    // MARK: - Conclusion

    @Test("Valid conclusion with matching cookie transitions to done")
    func validConclusionDone() {
        var listener = ListenerHandshake(configuration: makeListenerConfig())
        let cookie = generateCookie()
        let (packet, exts) = makeConclusionRequest(cookie: cookie)
        _ = listener.processConclusion(
            handshake: packet, extensions: exts, from: peerAddress, cookieSecret: cookieSecret
        )
        #expect(listener.state == .done)
    }

    @Test("Conclusion response includes HSRSP with negotiated latency")
    func conclusionResponseHasHSRSP() {
        var listener = ListenerHandshake(
            configuration: makeListenerConfig(senderDelay: 200, receiverDelay: 200)
        )
        let cookie = generateCookie()
        let (packet, exts) = makeConclusionRequest(
            cookie: cookie, senderDelay: 100, receiverDelay: 100
        )
        let actions = listener.processConclusion(
            handshake: packet, extensions: exts, from: peerAddress, cookieSecret: cookieSecret
        )

        guard
            case .sendPacket(_, let responseExts) = actions.first(where: { action in
                if case .sendPacket = action { return true }
                return false
            })
        else {
            #expect(Bool(false), "Expected sendPacket action")
            return
        }

        let hasHSRSP = responseExts.contains { ext in
            if case .hsrsp = ext { return true }
            return false
        }
        #expect(hasHSRSP)
    }

    // MARK: - Cookie validation

    @Test("Correct cookie is accepted")
    func correctCookieAccepted() {
        var listener = ListenerHandshake(configuration: makeListenerConfig())
        let cookie = generateCookie()
        let (packet, exts) = makeConclusionRequest(cookie: cookie)
        let actions = listener.processConclusion(
            handshake: packet, extensions: exts, from: peerAddress, cookieSecret: cookieSecret
        )

        let hasCompleted = actions.contains { action in
            if case .completed = action { return true }
            return false
        }
        #expect(hasCompleted)
    }

    @Test("Wrong cookie is rejected with rdvCookie")
    func wrongCookieRejected() {
        var listener = ListenerHandshake(configuration: makeListenerConfig())
        let (packet, exts) = makeConclusionRequest(cookie: 0xBAD_C00E)
        let actions = listener.processConclusion(
            handshake: packet, extensions: exts, from: peerAddress, cookieSecret: cookieSecret
        )

        let hasRejection = actions.contains { action in
            if case .error(.connectionRejected(.rdvCookie)) = action { return true }
            return false
        }
        #expect(hasRejection)
        #expect(listener.state == .failed)
    }

    @Test("Cookie from previous time bucket works (grace period)")
    func cookiePreviousBucketWorks() {
        var listener = ListenerHandshake(configuration: makeListenerConfig())
        let cookie = generateCookie(timeBucket: 99)
        let (packet, exts) = makeConclusionRequest(cookie: cookie)
        let actions = listener.processConclusion(
            handshake: packet, extensions: exts, from: peerAddress,
            cookieSecret: cookieSecret, timeBucket: 100
        )

        let hasCompleted = actions.contains { action in
            if case .completed = action { return true }
            return false
        }
        #expect(hasCompleted)
    }

    @Test("Cookie from expired bucket (2+ old) is rejected")
    func cookieExpiredBucketRejected() {
        var listener = ListenerHandshake(configuration: makeListenerConfig())
        let cookie = generateCookie(timeBucket: 97)
        let (packet, exts) = makeConclusionRequest(cookie: cookie)
        let actions = listener.processConclusion(
            handshake: packet, extensions: exts, from: peerAddress,
            cookieSecret: cookieSecret, timeBucket: 100
        )

        let hasRejection = actions.contains { action in
            if case .error(.connectionRejected(.rdvCookie)) = action { return true }
            return false
        }
        #expect(hasRejection)
    }

    // MARK: - Version validation

    @Test("Conclusion version must be 5")
    func conclusionVersionMustBe5() {
        var listener = ListenerHandshake(configuration: makeListenerConfig())
        let cookie = generateCookie()
        let packet = HandshakePacket(
            version: 4,
            handshakeType: .conclusion,
            srtSocketID: 0xBBBB,
            synCookie: cookie
        )
        let actions = listener.processConclusion(
            handshake: packet, extensions: [], from: peerAddress, cookieSecret: cookieSecret
        )

        let hasError = actions.contains { action in
            if case .error(.versionMismatch) = action { return true }
            return false
        }
        #expect(hasError)
    }

    @Test("Wrong handshake type: induction when expecting conclusion")
    func wrongHandshakeType() {
        var listener = ListenerHandshake(configuration: makeListenerConfig())
        let packet = HandshakePacket(
            version: 5,
            handshakeType: .induction,
            srtSocketID: 0xBBBB
        )
        let actions = listener.processConclusion(
            handshake: packet, extensions: [], from: peerAddress, cookieSecret: cookieSecret
        )

        let hasError = actions.contains { action in
            if case .error = action { return true }
            return false
        }
        #expect(hasError)
    }

    @Test("Second conclusion after done returns error")
    func secondConclusionAfterDone() {
        var listener = ListenerHandshake(configuration: makeListenerConfig())
        let cookie = generateCookie()
        let (packet, exts) = makeConclusionRequest(cookie: cookie)
        _ = listener.processConclusion(
            handshake: packet, extensions: exts, from: peerAddress, cookieSecret: cookieSecret
        )
        #expect(listener.state == .done)

        let actions = listener.processConclusion(
            handshake: packet, extensions: exts, from: peerAddress, cookieSecret: cookieSecret
        )
        let hasError = actions.contains { action in
            if case .error = action { return true }
            return false
        }
        #expect(hasError)
    }

    @Test("Peer socket ID in result")
    func peerSocketIDInResult() {
        var listener = ListenerHandshake(configuration: makeListenerConfig())
        let cookie = generateCookie()
        let (packet, exts) = makeConclusionRequest(cookie: cookie, callerSocketID: 0xCCCC)
        let actions = listener.processConclusion(
            handshake: packet, extensions: exts, from: peerAddress, cookieSecret: cookieSecret
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

        #expect(result.peerSocketID == 0xCCCC)
    }

    @Test("Initial state is idle")
    func initialStateIsIdle() {
        let listener = ListenerHandshake(configuration: makeListenerConfig())
        #expect(listener.state == .idle)
    }
}
