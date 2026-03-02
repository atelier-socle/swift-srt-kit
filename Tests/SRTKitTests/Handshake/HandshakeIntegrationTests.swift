// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("Handshake Integration Tests")
struct HandshakeIntegrationTests {
    private let cookieSecret: [UInt8] = [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x11, 0x22]
    private let callerAddress: SRTPeerAddress = .ipv4(0x0A00_0001)
    private let listenerAddress: SRTPeerAddress = .ipv4(0x0A00_0002)

    private func makeCallerConfig(
        streamID: String? = nil,
        passphrase: String? = nil,
        cipherType: UInt16 = 0,
        senderDelay: UInt16 = 120,
        receiverDelay: UInt16 = 120
    ) -> HandshakeConfiguration {
        HandshakeConfiguration(
            localSocketID: 0x1111,
            senderTSBPDDelay: senderDelay,
            receiverTSBPDDelay: receiverDelay,
            streamID: streamID,
            passphrase: passphrase,
            cipherType: cipherType
        )
    }

    private func makeListenerConfig(
        cipherType: UInt16 = 0,
        senderDelay: UInt16 = 120,
        receiverDelay: UInt16 = 120
    ) -> HandshakeConfiguration {
        HandshakeConfiguration(
            localSocketID: 0x2222,
            senderTSBPDDelay: senderDelay,
            receiverTSBPDDelay: receiverDelay,
            cipherType: cipherType
        )
    }

    /// Extracts the HandshakePacket and extensions from a sendPacket action.
    private func extractSendPacket(
        from actions: [HandshakeAction]
    ) -> (HandshakePacket, [HandshakeExtensionData])? {
        for action in actions {
            if case .sendPacket(let packet, let extensions) = action {
                return (packet, extensions)
            }
        }
        return nil
    }

    /// Extracts the HandshakeResult from a completed action.
    private func extractResult(from actions: [HandshakeAction]) -> HandshakeResult? {
        for action in actions {
            if case .completed(let result) = action {
                return result
            }
        }
        return nil
    }

    /// Extracts the sendPacket from a single action.
    private func extractSendPacketSingle(
        from action: HandshakeAction
    ) -> (HandshakePacket, [HandshakeExtensionData])? {
        if case .sendPacket(let packet, let extensions) = action {
            return (packet, extensions)
        }
        return nil
    }

    // MARK: - Happy path

    @Test("Full caller <-> listener handshake simulation")
    func fullHandshakeHappyPath() {
        var caller = CallerHandshake(configuration: makeCallerConfig())
        var listener = ListenerHandshake(configuration: makeListenerConfig())

        // Step 1: Caller starts -> sends induction
        let callerStartActions = caller.start()
        guard let (inductionReq, _) = extractSendPacket(from: callerStartActions) else {
            #expect(Bool(false), "Caller should send induction")
            return
        }
        #expect(caller.state == .inductionSent)

        // Step 2: Listener processes induction -> sends response
        let inductionRespAction = listener.processInduction(
            handshake: inductionReq, from: callerAddress, cookieSecret: cookieSecret
        )
        guard let (inductionResp, _) = extractSendPacketSingle(from: inductionRespAction) else {
            #expect(Bool(false), "Listener should send induction response")
            return
        }
        #expect(listener.state == .idle)  // Stateless

        // Step 3: Caller receives induction response -> sends conclusion
        let callerConclusionActions = caller.receive(
            handshake: inductionResp, extensions: [], from: listenerAddress
        )
        guard
            let (conclusionReq, conclusionExts) = extractSendPacket(
                from: callerConclusionActions
            )
        else {
            #expect(Bool(false), "Caller should send conclusion")
            return
        }
        #expect(caller.state == .conclusionSent)

        // Step 4: Listener processes conclusion -> done
        let listenerConclusionActions = listener.processConclusion(
            handshake: conclusionReq, extensions: conclusionExts,
            from: callerAddress, cookieSecret: cookieSecret
        )
        guard
            let (conclusionResp, conclusionRespExts) = extractSendPacket(
                from: listenerConclusionActions
            )
        else {
            #expect(Bool(false), "Listener should send conclusion response")
            return
        }
        let listenerResult = extractResult(from: listenerConclusionActions)
        #expect(listenerResult != nil)
        #expect(listener.state == .done)

        // Step 5: Caller receives conclusion response -> done
        let callerFinalActions = caller.receive(
            handshake: conclusionResp, extensions: conclusionRespExts, from: listenerAddress
        )
        let callerResult = extractResult(from: callerFinalActions)
        #expect(callerResult != nil)
        #expect(caller.state == .done)

        // Both sides should report correct peer socket IDs
        #expect(callerResult?.peerSocketID == 0x2222)
        #expect(listenerResult?.peerSocketID == 0x1111)
    }

    @Test("Happy path with StreamID")
    func happyPathWithStreamID() {
        var caller = CallerHandshake(configuration: makeCallerConfig(streamID: "live/stream1"))
        var listener = ListenerHandshake(configuration: makeListenerConfig())

        let callerStartActions = caller.start()
        guard let (inductionReq, _) = extractSendPacket(from: callerStartActions) else {
            #expect(Bool(false), "Expected induction")
            return
        }

        let inductionRespAction = listener.processInduction(
            handshake: inductionReq, from: callerAddress, cookieSecret: cookieSecret
        )
        guard let (inductionResp, _) = extractSendPacketSingle(from: inductionRespAction) else {
            #expect(Bool(false), "Expected induction response")
            return
        }

        let callerConclusionActions = caller.receive(
            handshake: inductionResp, extensions: [], from: listenerAddress
        )
        guard
            let (conclusionReq, conclusionExts) = extractSendPacket(
                from: callerConclusionActions
            )
        else {
            #expect(Bool(false), "Expected conclusion")
            return
        }

        // Verify SID is in the conclusion extensions
        let hasSID = conclusionExts.contains { ext in
            if case .streamID("live/stream1") = ext { return true }
            return false
        }
        #expect(hasSID)

        let listenerActions = listener.processConclusion(
            handshake: conclusionReq, extensions: conclusionExts,
            from: callerAddress, cookieSecret: cookieSecret
        )
        let listenerResult = extractResult(from: listenerActions)
        #expect(listenerResult?.streamID == "live/stream1")
    }

    @Test("Rejection by access control")
    func rejectionByAccessControl() {
        var caller = CallerHandshake(configuration: makeCallerConfig(streamID: "live/private"))
        var listener = ListenerHandshake(configuration: makeListenerConfig())

        let startActions = caller.start()
        guard let (inductionReq, _) = extractSendPacket(from: startActions) else { return }

        let inductionRespAction = listener.processInduction(
            handshake: inductionReq, from: callerAddress, cookieSecret: cookieSecret
        )
        guard let (inductionResp, _) = extractSendPacketSingle(from: inductionRespAction) else {
            return
        }

        let conclusionActions = caller.receive(
            handshake: inductionResp, extensions: [], from: listenerAddress
        )
        guard let (conclusionReq, conclusionExts) = extractSendPacket(from: conclusionActions)
        else { return }

        let listenerActions = listener.processConclusion(
            handshake: conclusionReq, extensions: conclusionExts,
            from: callerAddress, cookieSecret: cookieSecret,
            accessControl: { _ in .peer }
        )

        let hasRejection = listenerActions.contains { action in
            if case .error(.connectionRejected(.peer)) = action { return true }
            return false
        }
        #expect(hasRejection)
        #expect(listener.state == .failed)
    }

    @Test("Cookie replay attack: reusing old cookie is rejected")
    func cookieReplayAttack() {
        var listener = ListenerHandshake(configuration: makeListenerConfig())

        // Generate cookie at time bucket 50
        let oldCookie = CookieGenerator.generate(
            peerAddress: callerAddress, peerPort: 0, secret: cookieSecret, timeBucket: 50
        )

        let packet = HandshakePacket(
            version: 5,
            handshakeType: .conclusion,
            srtSocketID: 0x1111,
            synCookie: oldCookie
        )
        let hsreq = SRTHandshakeExtension(
            srtVersion: 0x0001_0501,
            srtFlags: [.tsbpdSender, .tsbpdReceiver],
            receiverTSBPDDelay: 120, senderTSBPDDelay: 120
        )

        // Try at time bucket 100 (way past expiry)
        let actions = listener.processConclusion(
            handshake: packet, extensions: [.hsreq(hsreq)],
            from: callerAddress, cookieSecret: cookieSecret, timeBucket: 100
        )

        let hasRejection = actions.contains { action in
            if case .error(.connectionRejected(.rdvCookie)) = action { return true }
            return false
        }
        #expect(hasRejection)
    }

}
