// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("CallerHandshake Coverage Tests")
struct CallerHandshakeCoverageTests {
    private func makeConfig(
        localSocketID: UInt32 = 0x1234,
        streamID: String? = nil,
        passphrase: String? = nil,
        cipherType: UInt16 = 0
    ) -> HandshakeConfiguration {
        HandshakeConfiguration(
            localSocketID: localSocketID,
            streamID: streamID,
            passphrase: passphrase,
            cipherType: cipherType
        )
    }

    private func makeInductionResponse(
        cookie: UInt32 = 0xABCD,
        peerSocketID: UInt32 = 0x5678,
        version: UInt32 = 5,
        handshakeType: HandshakePacket.HandshakeType = .induction
    ) -> HandshakePacket {
        HandshakePacket(
            version: version,
            extensionField: 0x4A17,
            handshakeType: handshakeType,
            srtSocketID: peerSocketID,
            synCookie: cookie
        )
    }

    // MARK: - start() called when not in idle state

    @Test("start() in inductionSent state returns error")
    func startWhenInductionSent() {
        var caller = CallerHandshake(configuration: makeConfig())
        let firstActions = caller.start()
        #expect(caller.state == .inductionSent)
        #expect(!firstActions.isEmpty)

        let secondActions = caller.start()
        let hasError = secondActions.contains { action in
            if case .error(.handshakeFailed) = action { return true }
            return false
        }
        #expect(hasError)
        #expect(secondActions.count == 1)
    }

    @Test("start() in conclusionSent state returns error")
    func startWhenConclusionSent() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        _ = caller.receive(
            handshake: makeInductionResponse(),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )
        #expect(caller.state == .conclusionSent)

        let actions = caller.start()
        let hasError = actions.contains { action in
            if case .error(.handshakeFailed) = action { return true }
            return false
        }
        #expect(hasError)
    }

    @Test("start() in done state returns error")
    func startWhenDone() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        _ = caller.receive(
            handshake: makeInductionResponse(),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )
        let conclusionPacket = HandshakePacket(
            version: 5, handshakeType: .conclusion, srtSocketID: 0x5678
        )
        let hsrsp = SRTHandshakeExtension(
            srtVersion: 0x0001_0501,
            srtFlags: [.tsbpdSender, .tsbpdReceiver],
            receiverTSBPDDelay: 120,
            senderTSBPDDelay: 120
        )
        _ = caller.receive(
            handshake: conclusionPacket,
            extensions: [.hsrsp(hsrsp)],
            from: .ipv4(0x7F00_0001)
        )
        #expect(caller.state == .done)

        let actions = caller.start()
        let hasError = actions.contains { action in
            if case .error(.handshakeFailed) = action { return true }
            return false
        }
        #expect(hasError)
    }

    @Test("start() in failed state returns error")
    func startWhenFailed() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        _ = caller.timeout()
        #expect(caller.state == .failed)

        let actions = caller.start()
        let hasError = actions.contains { action in
            if case .error(.handshakeFailed) = action { return true }
            return false
        }
        #expect(hasError)
    }

    // MARK: - timeout() in various states

    @Test("timeout() in idle returns handshakeFailed about not started")
    func timeoutInIdle() {
        var caller = CallerHandshake(configuration: makeConfig())
        #expect(caller.state == .idle)
        let action = caller.timeout()

        if case .error(.handshakeFailed(let msg)) = action {
            #expect(msg.contains("Timeout"))
        } else {
            Issue.record("Expected handshakeFailed error")
        }
    }

    @Test("timeout() in conclusionSent transitions to failed")
    func timeoutInConclusionSent() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        _ = caller.receive(
            handshake: makeInductionResponse(),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )
        #expect(caller.state == .conclusionSent)

        let action = caller.timeout()
        if case .error(.handshakeTimeout) = action {
            #expect(caller.state == .failed)
        } else {
            Issue.record("Expected handshakeTimeout error")
        }
    }

    @Test("timeout() in done state returns generic error")
    func timeoutInDone() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        _ = caller.receive(
            handshake: makeInductionResponse(),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )
        let conclusionPacket = HandshakePacket(
            version: 5, handshakeType: .conclusion, srtSocketID: 0x5678
        )
        let hsrsp = SRTHandshakeExtension(
            srtVersion: 0x0001_0501,
            srtFlags: [.tsbpdSender, .tsbpdReceiver],
            receiverTSBPDDelay: 120,
            senderTSBPDDelay: 120
        )
        _ = caller.receive(
            handshake: conclusionPacket,
            extensions: [.hsrsp(hsrsp)],
            from: .ipv4(0x7F00_0001)
        )
        #expect(caller.state == .done)

        let action = caller.timeout()
        if case .error(.handshakeFailed(let msg)) = action {
            #expect(msg.contains("Timeout"))
        } else {
            Issue.record("Expected handshakeFailed error for done state timeout")
        }
    }

    @Test("timeout() in failed state returns generic error")
    func timeoutInFailed() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        _ = caller.timeout()
        #expect(caller.state == .failed)

        let action = caller.timeout()
        if case .error(.handshakeFailed(let msg)) = action {
            #expect(msg.contains("Timeout"))
        } else {
            Issue.record("Expected handshakeFailed error for failed state timeout")
        }
    }

}

@Suite("CallerHandshake Coverage Tests Part 2")
struct CallerHandshakeCoverageTests2 {
    private func makeConfig(
        localSocketID: UInt32 = 0x1234,
        streamID: String? = nil,
        passphrase: String? = nil,
        cipherType: UInt16 = 0
    ) -> HandshakeConfiguration {
        HandshakeConfiguration(
            localSocketID: localSocketID,
            streamID: streamID,
            passphrase: passphrase,
            cipherType: cipherType
        )
    }

    private func makeInductionResponse(
        cookie: UInt32 = 0xABCD,
        peerSocketID: UInt32 = 0x5678,
        version: UInt32 = 5,
        handshakeType: HandshakePacket.HandshakeType = .induction
    ) -> HandshakePacket {
        HandshakePacket(
            version: version,
            extensionField: 0x4A17,
            handshakeType: handshakeType,
            srtSocketID: peerSocketID,
            synCookie: cookie
        )
    }

    // MARK: - receive() with wrong handshake type in induction response

    @Test("Induction response with conclusion type produces error")
    func inductionResponseWrongTypConclusion() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()

        let badPacket = makeInductionResponse(handshakeType: .conclusion)
        let actions = caller.receive(
            handshake: badPacket, extensions: [], from: .ipv4(0x7F00_0001)
        )

        let hasError = actions.contains { action in
            if case .error(.handshakeFailed(let msg)) = action {
                return msg.contains("Expected induction")
            }
            return false
        }
        #expect(hasError)
        #expect(caller.state == .failed)
    }

    @Test("Induction response with waveahand type produces error")
    func inductionResponseWrongTypeWaveahand() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()

        let badPacket = makeInductionResponse(handshakeType: .waveahand)
        let actions = caller.receive(
            handshake: badPacket, extensions: [], from: .ipv4(0x7F00_0001)
        )

        let hasError = actions.contains { action in
            if case .error(.handshakeFailed) = action { return true }
            return false
        }
        #expect(hasError)
        #expect(caller.state == .failed)
    }

    @Test("Induction response with done type produces error")
    func inductionResponseWrongTypeDone() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()

        let badPacket = makeInductionResponse(handshakeType: .done)
        let actions = caller.receive(
            handshake: badPacket, extensions: [], from: .ipv4(0x7F00_0001)
        )

        let hasError = actions.contains { action in
            if case .error(.handshakeFailed) = action { return true }
            return false
        }
        #expect(hasError)
        #expect(caller.state == .failed)
    }

    // MARK: - receive() with version != 5

    @Test("Induction response with version 4 produces versionMismatch")
    func inductionResponseVersion4() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()

        let badPacket = makeInductionResponse(version: 4)
        let actions = caller.receive(
            handshake: badPacket, extensions: [], from: .ipv4(0x7F00_0001)
        )

        let hasVersionError = actions.contains { action in
            if case .error(.versionMismatch) = action { return true }
            return false
        }
        #expect(hasVersionError)
        #expect(caller.state == .failed)
    }

    @Test("Induction response with version 3 produces versionMismatch")
    func inductionResponseVersion3() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()

        let badPacket = makeInductionResponse(version: 3)
        let actions = caller.receive(
            handshake: badPacket, extensions: [], from: .ipv4(0x7F00_0001)
        )

        let hasVersionError = actions.contains { action in
            if case .error(.versionMismatch) = action { return true }
            return false
        }
        #expect(hasVersionError)
        #expect(caller.state == .failed)
    }

    @Test("Induction response with version 6 produces versionMismatch")
    func inductionResponseVersion6() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()

        let badPacket = makeInductionResponse(version: 6)
        let actions = caller.receive(
            handshake: badPacket, extensions: [], from: .ipv4(0x7F00_0001)
        )

        let hasVersionError = actions.contains { action in
            if case .error(.versionMismatch) = action { return true }
            return false
        }
        #expect(hasVersionError)
        #expect(caller.state == .failed)
    }

    @Test("Induction response with version 0 produces versionMismatch")
    func inductionResponseVersion0() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()

        let badPacket = makeInductionResponse(version: 0)
        let actions = caller.receive(
            handshake: badPacket, extensions: [], from: .ipv4(0x7F00_0001)
        )

        let hasVersionError = actions.contains { action in
            if case .error(.versionMismatch) = action { return true }
            return false
        }
        #expect(hasVersionError)
        #expect(caller.state == .failed)
    }

    // MARK: - Rejection with wire-encoded offset (1000+)

    @Test("Conclusion with 1000-offset rejection code produces connectionRejected")
    func rejectionWith1000Offset() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        _ = caller.receive(
            handshake: makeInductionResponse(),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )

        let rejPacket = HandshakePacket(
            version: 5,
            handshakeType: .init(rawValue: 1000 + SRTRejectionReason.badSecret.rawValue),
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
        #expect(caller.state == .failed)
    }

    @Test("Conclusion with unknown rejection code produces connectionRejected unknown")
    func rejectionUnknownCode() {
        var caller = CallerHandshake(configuration: makeConfig())
        _ = caller.start()
        _ = caller.receive(
            handshake: makeInductionResponse(),
            extensions: [],
            from: .ipv4(0x7F00_0001)
        )

        let rejPacket = HandshakePacket(
            version: 5,
            handshakeType: .init(rawValue: 9999),
            srtSocketID: 0x5678
        )
        let actions = caller.receive(
            handshake: rejPacket, extensions: [], from: .ipv4(0x7F00_0001)
        )

        let hasRejection = actions.contains { action in
            if case .error(.connectionRejected(.unknown)) = action { return true }
            return false
        }
        #expect(hasRejection)
        #expect(caller.state == .failed)
    }
}
