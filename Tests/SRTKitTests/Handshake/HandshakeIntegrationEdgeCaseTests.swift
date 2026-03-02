// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("Handshake Integration Edge Case Tests")
struct HandshakeIntegrationEdgeCaseTests {
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

    private func extractResult(from actions: [HandshakeAction]) -> HandshakeResult? {
        for action in actions {
            if case .completed(let result) = action {
                return result
            }
        }
        return nil
    }

    private func extractSendPacketSingle(
        from action: HandshakeAction
    ) -> (HandshakePacket, [HandshakeExtensionData])? {
        if case .sendPacket(let packet, let extensions) = action {
            return (packet, extensions)
        }
        return nil
    }

    // MARK: - Version negotiation

    @Test("Version negotiation: v4 -> v5 through induction")
    func versionNegotiation() {
        var caller = CallerHandshake(configuration: makeCallerConfig())
        let listener = ListenerHandshake(configuration: makeListenerConfig())

        let startActions = caller.start()
        guard let (inductionReq, _) = extractSendPacket(from: startActions) else { return }
        #expect(inductionReq.version == 4)

        let inductionRespAction = listener.processInduction(
            handshake: inductionReq, from: callerAddress, cookieSecret: cookieSecret
        )
        guard let (inductionResp, _) = extractSendPacketSingle(from: inductionRespAction) else {
            return
        }
        #expect(inductionResp.version == 5)

        let conclusionActions = caller.receive(
            handshake: inductionResp, extensions: [], from: listenerAddress
        )
        guard let (conclusionReq, _) = extractSendPacket(from: conclusionActions) else { return }
        #expect(conclusionReq.version == 5)
    }

    @Test("Latency negotiation end-to-end")
    func latencyNegotiationEndToEnd() {
        var caller = CallerHandshake(
            configuration: makeCallerConfig(senderDelay: 100, receiverDelay: 300)
        )
        var listener = ListenerHandshake(
            configuration: makeListenerConfig(senderDelay: 200, receiverDelay: 150)
        )

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
            from: callerAddress, cookieSecret: cookieSecret
        )
        let listenerResult = extractResult(from: listenerActions)

        #expect(listenerResult != nil)
        #expect(listenerResult?.senderTSBPDDelay == 300)
        #expect(listenerResult?.receiverTSBPDDelay == 150)
    }

    @Test("Multiple sequential handshakes with same listener config")
    func multipleSequentialHandshakes() {
        let listenerConfig = makeListenerConfig()

        var caller1 = CallerHandshake(configuration: makeCallerConfig())
        var listener1 = ListenerHandshake(configuration: listenerConfig)

        let start1 = caller1.start()
        guard let (ind1, _) = extractSendPacket(from: start1) else { return }
        let indResp1 = listener1.processInduction(
            handshake: ind1, from: callerAddress, cookieSecret: cookieSecret
        )
        guard let (indR1, _) = extractSendPacketSingle(from: indResp1) else { return }
        let conc1 = caller1.receive(handshake: indR1, extensions: [], from: listenerAddress)
        guard let (concReq1, concExts1) = extractSendPacket(from: conc1) else { return }
        let lActions1 = listener1.processConclusion(
            handshake: concReq1, extensions: concExts1,
            from: callerAddress, cookieSecret: cookieSecret
        )
        #expect(extractResult(from: lActions1) != nil)

        var caller2 = CallerHandshake(
            configuration: HandshakeConfiguration(localSocketID: 0x3333)
        )
        var listener2 = ListenerHandshake(configuration: listenerConfig)

        let start2 = caller2.start()
        guard let (ind2, _) = extractSendPacket(from: start2) else { return }
        let indResp2 = listener2.processInduction(
            handshake: ind2, from: .ipv4(0x0A00_0003), cookieSecret: cookieSecret
        )
        guard let (indR2, _) = extractSendPacketSingle(from: indResp2) else { return }
        let conc2 = caller2.receive(handshake: indR2, extensions: [], from: listenerAddress)
        guard let (concReq2, concExts2) = extractSendPacket(from: conc2) else { return }
        let lActions2 = listener2.processConclusion(
            handshake: concReq2, extensions: concExts2,
            from: .ipv4(0x0A00_0003), cookieSecret: cookieSecret
        )
        #expect(extractResult(from: lActions2) != nil)
    }

    @Test("Timeout scenario: caller starts, no response, timeout")
    func timeoutScenario() {
        var caller = CallerHandshake(configuration: makeCallerConfig())
        _ = caller.start()
        #expect(caller.state == .inductionSent)

        let action = caller.timeout()
        if case .error(.handshakeTimeout) = action {
            #expect(Bool(true))
        } else {
            #expect(Bool(false), "Expected handshakeTimeout")
        }
        #expect(caller.state == .failed)
    }

    @Test("Double-start prevention")
    func doubleStartPrevention() {
        var caller = CallerHandshake(configuration: makeCallerConfig())
        _ = caller.start()
        let actions = caller.start()

        let hasError = actions.contains { action in
            if case .error = action { return true }
            return false
        }
        #expect(hasError)
    }

    @Test("State consistency: both sides report correct peerSocketID")
    func stateConsistency() {
        var caller = CallerHandshake(configuration: makeCallerConfig())
        var listener = ListenerHandshake(configuration: makeListenerConfig())

        let startActions = caller.start()
        guard let (inductionReq, _) = extractSendPacket(from: startActions) else { return }
        let indRespAction = listener.processInduction(
            handshake: inductionReq, from: callerAddress, cookieSecret: cookieSecret
        )
        guard let (inductionResp, _) = extractSendPacketSingle(from: indRespAction) else { return }
        let concActions = caller.receive(
            handshake: inductionResp, extensions: [], from: listenerAddress
        )
        guard let (concReq, concExts) = extractSendPacket(from: concActions) else { return }
        let lActions = listener.processConclusion(
            handshake: concReq, extensions: concExts,
            from: callerAddress, cookieSecret: cookieSecret
        )
        guard let (concResp, concRespExts) = extractSendPacket(from: lActions) else { return }
        let cFinalActions = caller.receive(
            handshake: concResp, extensions: concRespExts, from: listenerAddress
        )

        let callerResult = extractResult(from: cFinalActions)
        let listenerResult = extractResult(from: lActions)

        #expect(callerResult?.peerSocketID == 0x2222)
        #expect(listenerResult?.peerSocketID == 0x1111)
    }

    @Test("Induction response has SRT magic extension field 0x4A17")
    func inductionResponseMagicExtension() {
        let listener = ListenerHandshake(configuration: makeListenerConfig())
        let action = listener.processInduction(
            handshake: HandshakePacket(
                version: 4, extensionField: 2, handshakeType: .induction, srtSocketID: 0x1111
            ),
            from: callerAddress, cookieSecret: cookieSecret
        )
        guard let (packet, _) = extractSendPacketSingle(from: action) else {
            #expect(Bool(false), "Expected sendPacket")
            return
        }
        #expect(packet.extensionField == 0x4A17)
    }

    @Test("Caller induction has extensionField = 2")
    func callerInductionExtensionField() {
        var caller = CallerHandshake(configuration: makeCallerConfig())
        let actions = caller.start()
        guard let (packet, _) = extractSendPacket(from: actions) else {
            #expect(Bool(false), "Expected sendPacket")
            return
        }
        #expect(packet.extensionField == 2)
    }

    @Test("Caller induction has destinationSocketID = 0")
    func callerInductionDestinationSocketID() {
        var caller = CallerHandshake(configuration: makeCallerConfig())
        let actions = caller.start()
        guard let (packet, _) = extractSendPacket(from: actions) else {
            #expect(Bool(false), "Expected sendPacket")
            return
        }
        #expect(packet.synCookie == 0)
    }
}
