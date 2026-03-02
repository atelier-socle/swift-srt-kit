// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTEncryptionError Tests")
struct SRTEncryptionErrorTests {
    @Test("Each error case has a meaningful description")
    func descriptions() {
        let errors: [SRTEncryptionError] = [
            .passphraseTooShort(length: 5),
            .passphraseTooLong(length: 100),
            .invalidSaltSize(got: 8),
            .invalidKeySize(got: 10, expected: 16),
            .keyWrapIntegrityFailure,
            .invalidKeyDataLength(got: 15),
            .gcmAuthenticationFailure,
            .payloadTooShort(got: 10, minimumExpected: 16),
            .noKeyAvailable(keyIndex: .even),
            .notConfigured
        ]
        for err in errors {
            #expect(!err.description.isEmpty)
        }
    }

    @Test("Equatable conformance")
    func equatable() {
        #expect(
            SRTEncryptionError.passphraseTooShort(length: 5)
                == SRTEncryptionError.passphraseTooShort(length: 5))
        #expect(
            SRTEncryptionError.passphraseTooShort(length: 5)
                != SRTEncryptionError.passphraseTooShort(length: 6))
        #expect(
            SRTEncryptionError.keyWrapIntegrityFailure
                == SRTEncryptionError.keyWrapIntegrityFailure)
        #expect(
            SRTEncryptionError.keyWrapIntegrityFailure
                != SRTEncryptionError.gcmAuthenticationFailure)
    }

    @Test("passphraseTooShort includes length")
    func passphraseShortLength() {
        let err = SRTEncryptionError.passphraseTooShort(length: 7)
        #expect(err.description.contains("7"))
    }

    @Test("noKeyAvailable includes key index")
    func noKeyIndex() {
        let err = SRTEncryptionError.noKeyAvailable(keyIndex: .odd)
        #expect(err.description.contains("odd"))
    }

    @Test("CipherMode descriptions")
    func cipherModeDescriptions() {
        #expect(CipherMode.ctr.description == "AES-CTR")
        #expect(CipherMode.gcm.description == "AES-GCM")
    }
}
