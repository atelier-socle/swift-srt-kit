// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("ListenerHandshake Edge Case Tests")
struct ListenerHandshakeEdgeCaseTests {
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

    // MARK: - Latency negotiation

    @Test("Caller 100ms, listener 200ms -> 200ms (max)")
    func latencyCallerLower() {
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
            case .completed(let result) = actions.first(where: { action in
                if case .completed = action { return true }
                return false
            })
        else {
            #expect(Bool(false), "Expected completed action")
            return
        }

        #expect(result.senderTSBPDDelay == 200)
        #expect(result.receiverTSBPDDelay == 200)
    }

    @Test("Caller 500ms, listener 120ms -> 500ms (max)")
    func latencyCallerHigher() {
        var listener = ListenerHandshake(
            configuration: makeListenerConfig(senderDelay: 120, receiverDelay: 120)
        )
        let cookie = generateCookie()
        let (packet, exts) = makeConclusionRequest(
            cookie: cookie, senderDelay: 500, receiverDelay: 500
        )
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

        #expect(result.senderTSBPDDelay == 500)
    }

    @Test("Symmetric latency: same values both sides")
    func latencySymmetric() {
        var listener = ListenerHandshake(
            configuration: makeListenerConfig(senderDelay: 120, receiverDelay: 120)
        )
        let cookie = generateCookie()
        let (packet, exts) = makeConclusionRequest(
            cookie: cookie, senderDelay: 120, receiverDelay: 120
        )
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

        #expect(result.senderTSBPDDelay == 120)
        #expect(result.receiverTSBPDDelay == 120)
    }

    // MARK: - StreamID

    @Test("Conclusion with SID has streamID in result")
    func streamIDInResult() {
        var listener = ListenerHandshake(configuration: makeListenerConfig())
        let cookie = generateCookie()
        let (packet, exts) = makeConclusionRequest(cookie: cookie, streamID: "live/test")
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

        #expect(result.streamID == "live/test")
    }

    @Test("Conclusion without SID has nil streamID")
    func noStreamIDInResult() {
        var listener = ListenerHandshake(configuration: makeListenerConfig())
        let cookie = generateCookie()
        let (packet, exts) = makeConclusionRequest(cookie: cookie)
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

        #expect(result.streamID == nil)
    }

    // MARK: - Access control

    @Test("Access control handler returns nil -> accepted")
    func accessControlAccepted() {
        var listener = ListenerHandshake(configuration: makeListenerConfig())
        let cookie = generateCookie()
        let (packet, exts) = makeConclusionRequest(cookie: cookie, streamID: "live/ok")
        let actions = listener.processConclusion(
            handshake: packet, extensions: exts, from: peerAddress,
            cookieSecret: cookieSecret,
            accessControl: { _ in nil }
        )

        let hasCompleted = actions.contains { action in
            if case .completed = action { return true }
            return false
        }
        #expect(hasCompleted)
    }

    @Test("Access control handler returns .peer -> rejected")
    func accessControlRejectedPeer() {
        var listener = ListenerHandshake(configuration: makeListenerConfig())
        let cookie = generateCookie()
        let (packet, exts) = makeConclusionRequest(cookie: cookie, streamID: "live/bad")
        let actions = listener.processConclusion(
            handshake: packet, extensions: exts, from: peerAddress,
            cookieSecret: cookieSecret,
            accessControl: { _ in .peer }
        )

        let hasRejection = actions.contains { action in
            if case .error(.connectionRejected(.peer)) = action { return true }
            return false
        }
        #expect(hasRejection)
        #expect(listener.state == .failed)
    }

    @Test("Access control handler returns .resource -> rejected")
    func accessControlRejectedResource() {
        var listener = ListenerHandshake(configuration: makeListenerConfig())
        let cookie = generateCookie()
        let (packet, exts) = makeConclusionRequest(cookie: cookie, streamID: "live/full")
        let actions = listener.processConclusion(
            handshake: packet, extensions: exts, from: peerAddress,
            cookieSecret: cookieSecret,
            accessControl: { _ in .resource }
        )

        let hasRejection = actions.contains { action in
            if case .error(.connectionRejected(.resource)) = action { return true }
            return false
        }
        #expect(hasRejection)
    }

    @Test("No access control handler: accepted without SID validation")
    func noAccessControlHandler() {
        var listener = ListenerHandshake(configuration: makeListenerConfig())
        let cookie = generateCookie()
        let (packet, exts) = makeConclusionRequest(cookie: cookie, streamID: "anything")
        let actions = listener.processConclusion(
            handshake: packet, extensions: exts, from: peerAddress,
            cookieSecret: cookieSecret,
            accessControl: nil
        )

        let hasCompleted = actions.contains { action in
            if case .completed = action { return true }
            return false
        }
        #expect(hasCompleted)
    }

    // MARK: - Encryption

    @Test("Caller encrypted, listener not -> rejected with unsecure")
    func encryptionMismatchCallerEncrypted() {
        var listener = ListenerHandshake(configuration: makeListenerConfig(cipherType: 0))
        let cookie = generateCookie()
        let (packet, _) = makeConclusionRequest(cookie: cookie, encryptionField: 2)
        let km = KeyMaterialPacket(
            cipher: .aesCTR, salt: Array(repeating: 0, count: 16),
            keyLength: 16, wrappedKeys: Array(repeating: 0, count: 24)
        )
        let actions = listener.processConclusion(
            handshake: packet,
            extensions: [
                .hsreq(
                    SRTHandshakeExtension(
                        srtVersion: 0x0001_0501,
                        srtFlags: [.tsbpdSender, .tsbpdReceiver],
                        receiverTSBPDDelay: 120, senderTSBPDDelay: 120
                    )),
                .kmreq(km)
            ],
            from: peerAddress, cookieSecret: cookieSecret
        )

        let hasRejection = actions.contains { action in
            if case .error(.connectionRejected(.unsecure)) = action { return true }
            return false
        }
        #expect(hasRejection)
    }
}
