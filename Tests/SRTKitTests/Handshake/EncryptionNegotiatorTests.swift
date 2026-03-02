// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("EncryptionNegotiator Tests")
struct EncryptionNegotiatorTests {
    @Test("Both unencrypted -> noEncryption")
    func bothUnencrypted() {
        let result = EncryptionNegotiator.negotiate(
            callerCipher: 0, listenerCipher: 0,
            callerHasPassphrase: false, listenerHasPassphrase: false
        )
        #expect(result == .noEncryption)
    }

    @Test("Both AES-128 -> accepted(cipher: 2)")
    func bothAES128() {
        let result = EncryptionNegotiator.negotiate(
            callerCipher: 2, listenerCipher: 2,
            callerHasPassphrase: true, listenerHasPassphrase: true
        )
        #expect(result == .accepted(cipher: 2))
    }

    @Test("Both AES-256 -> accepted(cipher: 4)")
    func bothAES256() {
        let result = EncryptionNegotiator.negotiate(
            callerCipher: 4, listenerCipher: 4,
            callerHasPassphrase: true, listenerHasPassphrase: true
        )
        #expect(result == .accepted(cipher: 4))
    }

    @Test("Caller AES-128, listener AES-256 -> accepted(cipher: 4) listener wins")
    func callerAES128ListenerAES256() {
        let result = EncryptionNegotiator.negotiate(
            callerCipher: 2, listenerCipher: 4,
            callerHasPassphrase: true, listenerHasPassphrase: true
        )
        #expect(result == .accepted(cipher: 4))
    }

    @Test("Caller AES-256, listener AES-128 -> accepted(cipher: 2) listener wins")
    func callerAES256ListenerAES128() {
        let result = EncryptionNegotiator.negotiate(
            callerCipher: 4, listenerCipher: 2,
            callerHasPassphrase: true, listenerHasPassphrase: true
        )
        #expect(result == .accepted(cipher: 2))
    }

    @Test("Caller encrypted, listener no passphrase, enforce=true -> rejected")
    func callerEncryptedListenerNotEnforced() {
        let result = EncryptionNegotiator.negotiate(
            callerCipher: 2, listenerCipher: 0,
            callerHasPassphrase: true, listenerHasPassphrase: false,
            enforceEncryption: true
        )
        #expect(result == .rejected(reason: .unsecure))
    }

    @Test("Listener encrypted, caller no passphrase, enforce=true -> rejected")
    func listenerEncryptedCallerNotEnforced() {
        let result = EncryptionNegotiator.negotiate(
            callerCipher: 0, listenerCipher: 2,
            callerHasPassphrase: false, listenerHasPassphrase: true,
            enforceEncryption: true
        )
        #expect(result == .rejected(reason: .unsecure))
    }

    @Test("Caller encrypted, listener no passphrase, enforce=false -> tolerated")
    func callerEncryptedTolerated() {
        let result = EncryptionNegotiator.negotiate(
            callerCipher: 2, listenerCipher: 0,
            callerHasPassphrase: true, listenerHasPassphrase: false,
            enforceEncryption: false
        )
        #expect(result == .accepted(cipher: 2))
    }

    @Test("Listener encrypted, caller no passphrase, enforce=false -> tolerated")
    func listenerEncryptedTolerated() {
        let result = EncryptionNegotiator.negotiate(
            callerCipher: 0, listenerCipher: 4,
            callerHasPassphrase: false, listenerHasPassphrase: true,
            enforceEncryption: false
        )
        #expect(result == .accepted(cipher: 4))
    }

    @Test("Both no passphrase, both cipher=0 -> noEncryption")
    func bothNoCipherNoPassphrase() {
        let result = EncryptionNegotiator.negotiate(
            callerCipher: 0, listenerCipher: 0,
            callerHasPassphrase: false, listenerHasPassphrase: false
        )
        #expect(result == .noEncryption)
    }

    @Test("AES-192 (cipher=3) both sides -> accepted(cipher: 3)")
    func bothAES192() {
        let result = EncryptionNegotiator.negotiate(
            callerCipher: 3, listenerCipher: 3,
            callerHasPassphrase: true, listenerHasPassphrase: true
        )
        #expect(result == .accepted(cipher: 3))
    }
}
