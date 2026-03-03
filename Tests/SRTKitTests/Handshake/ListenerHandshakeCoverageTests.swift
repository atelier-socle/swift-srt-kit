// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("ListenerHandshake Coverage Tests")
struct ListenerHandshakeCoverageTests {
    private func makeConfig(
        passphrase: String? = nil,
        cipherType: UInt16 = 0
    ) -> HandshakeConfiguration {
        HandshakeConfiguration(
            localSocketID: 0x1234,
            senderTSBPDDelay: 120,
            receiverTSBPDDelay: 120,
            passphrase: passphrase,
            cipherType: cipherType
        )
    }

    private let cookieSecret: [UInt8] = Array(repeating: 0xAA, count: 32)
    private let peerAddress: SRTPeerAddress = .ipv4(0x7F00_0001)

    private func makeConclusionPacket(
        cookie: UInt32 = 0,
        encryptionField: UInt16 = 0,
        socketID: UInt32 = 0xABCD
    ) -> HandshakePacket {
        HandshakePacket(
            version: 5,
            encryptionField: encryptionField,
            handshakeType: .conclusion,
            srtSocketID: socketID,
            synCookie: cookie,
            peerIPAddress: peerAddress
        )
    }

    /// Generate a valid cookie to use in conclusion tests.
    private func validCookie(timeBucket: UInt32 = 0) -> UInt32 {
        CookieGenerator.generate(
            peerAddress: peerAddress,
            peerPort: 0,
            secret: cookieSecret,
            timeBucket: timeBucket
        )
    }

    // MARK: - KMREQ when cipher is 0 (unsecure rejection)

    @Test("KMREQ received when cipher is 0 rejects with unsecure")
    func kmreqWhenNoCipherRejects() {
        var hs = ListenerHandshake(configuration: makeConfig(cipherType: 0))
        let cookie = validCookie()
        let conclusion = makeConclusionPacket(cookie: cookie)

        let km = KeyMaterialPacket(
            cipher: .aesCTR, salt: Array(repeating: 0, count: 16),
            keyLength: 16, wrappedKeys: Array(repeating: 0, count: 24)
        )
        let extensions: [HandshakeExtensionData] = [.kmreq(km)]

        let actions = hs.processConclusion(
            handshake: conclusion, extensions: extensions,
            from: peerAddress, cookieSecret: cookieSecret
        )
        let hasRejection = actions.contains { action in
            if case .error(let err) = action,
                case .connectionRejected = err
            {
                return true
            }
            return false
        }
        #expect(hasRejection)
        #expect(hs.state == .failed)
    }

    // MARK: - Encryption mismatch: listener expects crypto, caller has none

    @Test("Listener expects encryption but caller provides none")
    func encryptionMismatchRejectsUnsecure() {
        var hs = ListenerHandshake(
            configuration: makeConfig(passphrase: "testpassphrase", cipherType: 2))
        let cookie = validCookie()
        let conclusion = makeConclusionPacket(
            cookie: cookie, encryptionField: 0)

        let hsreq = SRTHandshakeExtension(
            srtVersion: 0x0001_0501,
            srtFlags: [.tsbpdSender, .tsbpdReceiver],
            receiverTSBPDDelay: 120,
            senderTSBPDDelay: 120
        )
        let actions = hs.processConclusion(
            handshake: conclusion,
            extensions: [.hsreq(hsreq)],
            from: peerAddress, cookieSecret: cookieSecret
        )
        let hasRejection = actions.contains { action in
            if case .error(let err) = action,
                case .connectionRejected = err
            {
                return true
            }
            return false
        }
        #expect(hasRejection)
        #expect(hs.state == .failed)
    }

    // MARK: - KMREQ unwrap with invalid key length

    @Test("KMREQ with invalid key length rejects")
    func kmreqInvalidKeyLengthRejects() {
        var hs = ListenerHandshake(
            configuration: makeConfig(passphrase: "testpassphrase", cipherType: 2))
        let cookie = validCookie()
        let conclusion = makeConclusionPacket(
            cookie: cookie, encryptionField: 2)

        let km = KeyMaterialPacket(
            cipher: .aesCTR, salt: Array(repeating: 0, count: 16),
            keyLength: 99, wrappedKeys: Array(repeating: 0, count: 24)
        )
        let actions = hs.processConclusion(
            handshake: conclusion,
            extensions: [
                .hsreq(
                    SRTHandshakeExtension(
                        srtVersion: 0x0001_0501,
                        srtFlags: [.tsbpdSender, .tsbpdReceiver],
                        receiverTSBPDDelay: 120,
                        senderTSBPDDelay: 120)),
                .kmreq(km)
            ],
            from: peerAddress, cookieSecret: cookieSecret
        )
        let hasRejection = actions.contains { action in
            if case .error = action { return true }
            return false
        }
        #expect(hasRejection)
    }

    // MARK: - KMREQ unwrap with wrong passphrase (catch path)

    @Test("KMREQ unwrap fails with wrong key material")
    func kmreqUnwrapFailsWithBadKeys() {
        var hs = ListenerHandshake(
            configuration: makeConfig(passphrase: "testpassphrase", cipherType: 2))
        let cookie = validCookie()
        let conclusion = makeConclusionPacket(
            cookie: cookie, encryptionField: 2)

        // Valid key length (16) but garbage wrapped keys → unwrap will throw
        let km = KeyMaterialPacket(
            cipher: .aesCTR, salt: Array(repeating: 0xBB, count: 16),
            keyLength: 16, wrappedKeys: Array(repeating: 0xCC, count: 24)
        )
        let actions = hs.processConclusion(
            handshake: conclusion,
            extensions: [
                .hsreq(
                    SRTHandshakeExtension(
                        srtVersion: 0x0001_0501,
                        srtFlags: [.tsbpdSender, .tsbpdReceiver],
                        receiverTSBPDDelay: 120,
                        senderTSBPDDelay: 120)),
                .kmreq(km)
            ],
            from: peerAddress, cookieSecret: cookieSecret
        )
        let hasError = actions.contains { action in
            if case .error = action { return true }
            return false
        }
        #expect(hasError)
    }

    // MARK: - KMREQ unwrap succeeds with valid key material

    @Test("KMREQ unwrap succeeds with valid keys")
    func kmreqUnwrapSucceeds() throws {
        let passphrase = "testpassphrase"
        let salt = KeyDerivation.generateSalt()
        let keySize = KeySize.aes128
        let kek = try KeyDerivation.deriveKEK(
            passphrase: passphrase, salt: salt, keySize: keySize)
        let sek = Array(repeating: UInt8(0x42), count: keySize.rawValue)
        let wrappedSEK = try KeyWrap.wrap(key: sek, withKEK: kek)

        var hs = ListenerHandshake(
            configuration: makeConfig(passphrase: passphrase, cipherType: 2))
        let cookie = validCookie()
        let conclusion = makeConclusionPacket(
            cookie: cookie, encryptionField: 2)

        let km = KeyMaterialPacket(
            cipher: .aesCTR, salt: salt,
            keyLength: UInt16(keySize.rawValue),
            wrappedKeys: wrappedSEK
        )
        let actions = hs.processConclusion(
            handshake: conclusion,
            extensions: [
                .hsreq(
                    SRTHandshakeExtension(
                        srtVersion: 0x0001_0501,
                        srtFlags: [.tsbpdSender, .tsbpdReceiver, .crypt],
                        receiverTSBPDDelay: 120,
                        senderTSBPDDelay: 120)),
                .kmreq(km)
            ],
            from: peerAddress, cookieSecret: cookieSecret
        )
        let hasCompleted = actions.contains { action in
            if case .completed = action { return true }
            return false
        }
        #expect(hasCompleted)
        // Result should include encryption keys
        for action in actions {
            if case .completed(let result) = action {
                #expect(result.encryptionSEK != nil)
                #expect(result.encryptionSalt != nil)
            }
        }
    }

    // MARK: - Access control rejection

    @Test("Access control handler can reject connection")
    func accessControlRejection() {
        var hs = ListenerHandshake(configuration: makeConfig())
        let cookie = validCookie()
        let conclusion = makeConclusionPacket(cookie: cookie)

        let actions = hs.processConclusion(
            handshake: conclusion,
            extensions: [.streamID("#!::r=live,m=publish")],
            from: peerAddress, cookieSecret: cookieSecret,
            accessControl: { _ in .peer }
        )
        let hasRejection = actions.contains { action in
            if case .error(let err) = action,
                case .connectionRejected = err
            {
                return true
            }
            return false
        }
        #expect(hasRejection)
        #expect(hs.state == .failed)
    }

    // MARK: - Timeout in various states

    @Test("Timeout in idle state returns error")
    func timeoutInIdleState() {
        var hs = ListenerHandshake(configuration: makeConfig())
        let action = hs.timeout()
        if case .error = action {
            // expected
        } else {
            #expect(Bool(false), "Expected error action")
        }
    }

    @Test("Timeout in done state returns error")
    func timeoutInDoneState() {
        var hs = ListenerHandshake(configuration: makeConfig())
        // Process a valid conclusion to get to done state
        let cookie = validCookie()
        let conclusion = makeConclusionPacket(cookie: cookie)
        _ = hs.processConclusion(
            handshake: conclusion, extensions: [],
            from: peerAddress, cookieSecret: cookieSecret
        )
        let action = hs.timeout()
        if case .error = action {
            // expected — timeout after done
        } else {
            #expect(Bool(false), "Expected error action")
        }
    }

    // MARK: - processConclusion in wrong state

    @Test("processConclusion in failed state returns error")
    func conclusionInFailedState() {
        var hs = ListenerHandshake(configuration: makeConfig())
        // Force failed state by sending a bad cookie
        let conclusion = makeConclusionPacket(cookie: 0xDEAD_BEEF)
        _ = hs.processConclusion(
            handshake: conclusion, extensions: [],
            from: peerAddress, cookieSecret: cookieSecret
        )
        #expect(hs.state == .failed)

        // Now try again in failed state
        let actions = hs.processConclusion(
            handshake: conclusion, extensions: [],
            from: peerAddress, cookieSecret: cookieSecret
        )
        let hasError = actions.contains { action in
            if case .error = action { return true }
            return false
        }
        #expect(hasError)
    }

    // MARK: - Wrong version rejects

    @Test("Version 4 conclusion is rejected")
    func version4Rejected() {
        var hs = ListenerHandshake(configuration: makeConfig())
        let cookie = validCookie()
        let conclusion = HandshakePacket(
            version: 4,
            handshakeType: .conclusion,
            srtSocketID: 0xABCD,
            synCookie: cookie,
            peerIPAddress: peerAddress
        )
        let actions = hs.processConclusion(
            handshake: conclusion, extensions: [],
            from: peerAddress, cookieSecret: cookieSecret
        )
        let hasVersionMismatch = actions.contains { action in
            if case .error(let err) = action,
                case .versionMismatch = err
            {
                return true
            }
            return false
        }
        #expect(hasVersionMismatch)
    }
}
