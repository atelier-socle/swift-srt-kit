// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTError Tests")
struct SRTErrorTests {
    @Test("connectionFailed has description")
    func connectionFailedDescription() {
        let error = SRTError.connectionFailed("timeout")
        #expect(error.description == "Connection failed: timeout")
    }

    @Test("connectionTimeout has description")
    func connectionTimeoutDescription() {
        let error = SRTError.connectionTimeout
        #expect(error.description == "Connection timed out")
    }

    @Test("connectionRejected has description")
    func connectionRejectedDescription() {
        let error = SRTError.connectionRejected(.badSecret)
        #expect(error.description.contains("rejected"))
    }

    @Test("connectionClosed has description")
    func connectionClosedDescription() {
        let error = SRTError.connectionClosed
        #expect(error.description == "Connection closed")
    }

    @Test("encryptionFailed has description")
    func encryptionFailedDescription() {
        let error = SRTError.encryptionFailed("key expired")
        #expect(error.description == "Encryption failed: key expired")
    }

    @Test("decryptionFailed has description")
    func decryptionFailedDescription() {
        let error = SRTError.decryptionFailed("bad key")
        #expect(error.description == "Decryption failed: bad key")
    }

    @Test("invalidPassphrase has description")
    func invalidPassphraseDescription() {
        let error = SRTError.invalidPassphrase
        #expect(error.description == "Invalid passphrase")
    }

    @Test("handshakeFailed has description")
    func handshakeFailedDescription() {
        let error = SRTError.handshakeFailed("protocol error")
        #expect(error.description == "Handshake failed: protocol error")
    }

    @Test("handshakeTimeout has description")
    func handshakeTimeoutDescription() {
        let error = SRTError.handshakeTimeout
        #expect(error.description == "Handshake timed out")
    }

    @Test("versionMismatch has description")
    func versionMismatchDescription() {
        let error = SRTError.versionMismatch
        #expect(error.description == "SRT version mismatch")
    }

    @Test("invalidPacket has description")
    func invalidPacketDescription() {
        let error = SRTError.invalidPacket("too short")
        #expect(error.description == "Invalid packet: too short")
    }

    @Test("packetTooLarge has description")
    func packetTooLargeDescription() {
        let error = SRTError.packetTooLarge(9999)
        #expect(error.description == "Packet too large: 9999 bytes")
    }

    @Test("invalidState has description")
    func invalidStateDescription() {
        let error = SRTError.invalidState(.closed)
        #expect(error.description.contains("closed"))
    }

    @Test("Pattern matching works for connection errors")
    func patternMatchingConnection() {
        let error = SRTError.connectionTimeout
        if case .connectionTimeout = error {
            #expect(true)
        } else {
            #expect(Bool(false), "Pattern matching failed")
        }
    }

    @Test("Pattern matching works for associated values")
    func patternMatchingAssociatedValue() {
        let error = SRTError.connectionRejected(.peer)
        if case .connectionRejected(let reason) = error {
            #expect(reason == .peer)
        } else {
            #expect(Bool(false), "Pattern matching failed")
        }
    }
}
