// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTOptionValidation Coverage Tests")
struct SRTOptionValidationCoverageTests {

    // MARK: - Passphrase exact boundary tests

    @Test("Passphrase exactly at min boundary (10 chars) is valid")
    func passphraseExactMin() {
        var options = SRTSocketOptions()
        options.passphrase = String(repeating: "x", count: 10)
        let errors = SRTOptionValidation.validate(options)
        let passphraseErrors = errors.filter {
            if case .passphraseTooShort = $0 { return true }
            if case .passphraseTooLong = $0 { return true }
            return false
        }
        #expect(passphraseErrors.isEmpty)
    }

    @Test("Passphrase exactly at max boundary (79 chars) is valid")
    func passphraseExactMax() {
        var options = SRTSocketOptions()
        options.passphrase = String(repeating: "z", count: 79)
        let errors = SRTOptionValidation.validate(options)
        let passphraseErrors = errors.filter {
            if case .passphraseTooShort = $0 { return true }
            if case .passphraseTooLong = $0 { return true }
            return false
        }
        #expect(passphraseErrors.isEmpty)
    }

    @Test("Passphrase 1 char below min (9 chars) returns passphraseTooShort")
    func passphrase1BelowMin() {
        var options = SRTSocketOptions()
        options.passphrase = String(repeating: "a", count: 9)
        let errors = SRTOptionValidation.validate(options)

        let hasTooShort = errors.contains {
            if case .passphraseTooShort(let length, let minimum) = $0 {
                return length == 9 && minimum == 10
            }
            return false
        }
        #expect(hasTooShort)
    }

    @Test("Passphrase 1 char above max (80 chars) returns passphraseTooLong")
    func passphrase1AboveMax() {
        var options = SRTSocketOptions()
        options.passphrase = String(repeating: "b", count: 80)
        let errors = SRTOptionValidation.validate(options)

        let hasTooLong = errors.contains {
            if case .passphraseTooLong(let length, let maximum) = $0 {
                return length == 80 && maximum == 79
            }
            return false
        }
        #expect(hasTooLong)
    }

    @Test("Passphrase of 1 char returns passphraseTooShort")
    func passphrase1Char() {
        var options = SRTSocketOptions()
        options.passphrase = "a"
        let errors = SRTOptionValidation.validate(options)

        let hasTooShort = errors.contains {
            if case .passphraseTooShort(let length, _) = $0 {
                return length == 1
            }
            return false
        }
        #expect(hasTooShort)
    }

    // MARK: - Payload size boundary tests

    @Test("Payload size at exact lower boundary (72) is valid")
    func payloadSizeLowerBoundary() {
        var options = SRTSocketOptions()
        options.maxPayloadSize = 72
        let errors = SRTOptionValidation.validate(options)
        let payloadErrors = errors.filter {
            if case .payloadSizeOutOfRange = $0 { return true }
            return false
        }
        #expect(payloadErrors.isEmpty)
    }

    @Test("Payload size at exact upper boundary (1500) is valid")
    func payloadSizeUpperBoundary() {
        var options = SRTSocketOptions()
        options.maxPayloadSize = 1500
        let errors = SRTOptionValidation.validate(options)
        let payloadErrors = errors.filter {
            if case .payloadSizeOutOfRange = $0 { return true }
            return false
        }
        #expect(payloadErrors.isEmpty)
    }

    @Test("Payload size 1 below lower boundary (71) returns error")
    func payloadSize1BelowLower() {
        var options = SRTSocketOptions()
        options.maxPayloadSize = 71
        let errors = SRTOptionValidation.validate(options)

        let hasError = errors.contains {
            if case .payloadSizeOutOfRange(let got, _) = $0 {
                return got == 71
            }
            return false
        }
        #expect(hasError)
    }

    @Test("Payload size 1 above upper boundary (1501) returns error")
    func payloadSize1AboveUpper() {
        var options = SRTSocketOptions()
        options.maxPayloadSize = 1501
        let errors = SRTOptionValidation.validate(options)

        let hasError = errors.contains {
            if case .payloadSizeOutOfRange(let got, _) = $0 {
                return got == 1501
            }
            return false
        }
        #expect(hasError)
    }

    @Test("Payload size 0 returns error")
    func payloadSizeZero() {
        var options = SRTSocketOptions()
        options.maxPayloadSize = 0
        let errors = SRTOptionValidation.validate(options)

        let hasError = errors.contains {
            if case .payloadSizeOutOfRange = $0 { return true }
            return false
        }
        #expect(hasError)
    }

    // MARK: - IP TTL boundary tests

    @Test("IP TTL at lower boundary (1) is valid")
    func ipTTLLowerBoundary() {
        var options = SRTSocketOptions()
        options.ipTTL = 1
        let errors = SRTOptionValidation.validate(options)
        let ttlErrors = errors.filter {
            if case .ipTTLOutOfRange = $0 { return true }
            return false
        }
        #expect(ttlErrors.isEmpty)
    }

    @Test("IP TTL at upper boundary (255) is valid")
    func ipTTLUpperBoundary() {
        var options = SRTSocketOptions()
        options.ipTTL = 255
        let errors = SRTOptionValidation.validate(options)
        let ttlErrors = errors.filter {
            if case .ipTTLOutOfRange = $0 { return true }
            return false
        }
        #expect(ttlErrors.isEmpty)
    }

    @Test("IP TTL 0 (below lower boundary) returns error")
    func ipTTLZero() {
        var options = SRTSocketOptions()
        options.ipTTL = 0
        let errors = SRTOptionValidation.validate(options)

        let hasError = errors.contains {
            if case .ipTTLOutOfRange(let got, _) = $0 {
                return got == 0
            }
            return false
        }
        #expect(hasError)
    }

    @Test("IP TTL 256 (above upper boundary) returns error")
    func ipTTL256() {
        var options = SRTSocketOptions()
        options.ipTTL = 256
        let errors = SRTOptionValidation.validate(options)

        let hasError = errors.contains {
            if case .ipTTLOutOfRange(let got, _) = $0 {
                return got == 256
            }
            return false
        }
        #expect(hasError)
    }

    // MARK: - IP TOS boundary tests

    @Test("IP TOS at lower boundary (0) is valid")
    func ipTOSLowerBoundary() {
        var options = SRTSocketOptions()
        options.ipTOS = 0
        let errors = SRTOptionValidation.validate(options)
        let tosErrors = errors.filter {
            if case .ipTOSOutOfRange = $0 { return true }
            return false
        }
        #expect(tosErrors.isEmpty)
    }

    @Test("IP TOS at upper boundary (255) is valid")
    func ipTOSUpperBoundary() {
        var options = SRTSocketOptions()
        options.ipTOS = 255
        let errors = SRTOptionValidation.validate(options)
        let tosErrors = errors.filter {
            if case .ipTOSOutOfRange = $0 { return true }
            return false
        }
        #expect(tosErrors.isEmpty)
    }

    @Test("IP TOS -1 (below lower boundary) returns error")
    func ipTOSNegative() {
        var options = SRTSocketOptions()
        options.ipTOS = -1
        let errors = SRTOptionValidation.validate(options)

        let hasError = errors.contains {
            if case .ipTOSOutOfRange(let got, _) = $0 {
                return got == -1
            }
            return false
        }
        #expect(hasError)
    }

    @Test("IP TOS 256 (above upper boundary) returns error")
    func ipTOS256() {
        var options = SRTSocketOptions()
        options.ipTOS = 256
        let errors = SRTOptionValidation.validate(options)

        let hasError = errors.contains {
            if case .ipTOSOutOfRange(let got, _) = $0 {
                return got == 256
            }
            return false
        }
        #expect(hasError)
    }

    // MARK: - Key rotation: preAnnounce > refreshRate

    @Test("preAnnounce > refreshRate returns kmPreAnnounceExceedsRefreshRate")
    func preAnnounceExceedsRefreshRate() {
        var options = SRTSocketOptions()
        options.kmPreAnnounce = 5000
        options.kmRefreshRate = 4000
        let errors = SRTOptionValidation.validate(options)

        let hasError = errors.contains {
            if case .kmPreAnnounceExceedsRefreshRate(let pre, let refresh) = $0 {
                return pre == 5000 && refresh == 4000
            }
            return false
        }
        #expect(hasError)
    }

    @Test("preAnnounce == refreshRate is valid (not strictly greater)")
    func preAnnounceEqualsRefreshRate() {
        var options = SRTSocketOptions()
        options.kmPreAnnounce = 3000
        options.kmRefreshRate = 3000
        let errors = SRTOptionValidation.validate(options)

        let hasError = errors.contains {
            if case .kmPreAnnounceExceedsRefreshRate = $0 { return true }
            return false
        }
        #expect(!hasError)
    }

    @Test("preAnnounce < refreshRate is valid")
    func preAnnounceBelowRefreshRate() {
        var options = SRTSocketOptions()
        options.kmPreAnnounce = 1000
        options.kmRefreshRate = 2000
        let errors = SRTOptionValidation.validate(options)

        let hasError = errors.contains {
            if case .kmPreAnnounceExceedsRefreshRate = $0 { return true }
            return false
        }
        #expect(!hasError)
    }

}

@Suite("SRTOptionValidation Coverage Tests Part 2")
struct SRTOptionValidationCoverageTests2 {

    // MARK: - Buffer size boundaries

    @Test("Receive buffer size 0 returns bufferSizeTooSmall")
    func receiveBufferZero() {
        var options = SRTSocketOptions()
        options.receiveBufferSize = 0
        let errors = SRTOptionValidation.validate(options)

        let hasError = errors.contains {
            if case .bufferSizeTooSmall(let name, _, _) = $0 {
                return name == "receiveBuffer"
            }
            return false
        }
        #expect(hasError)
    }

    @Test("Flow window size 0 returns bufferSizeTooSmall")
    func flowWindowZero() {
        var options = SRTSocketOptions()
        options.flowWindowSize = 0
        let errors = SRTOptionValidation.validate(options)

        let hasError = errors.contains {
            if case .bufferSizeTooSmall(let name, _, _) = $0 {
                return name == "flowWindow"
            }
            return false
        }
        #expect(hasError)
    }

    @Test("All buffer sizes at minimum (1) are valid")
    func allBufferSizesAtMinimum() {
        var options = SRTSocketOptions()
        options.sendBufferSize = 1
        options.receiveBufferSize = 1
        options.flowWindowSize = 1
        let errors = SRTOptionValidation.validate(options)

        let bufferErrors = errors.filter {
            if case .bufferSizeTooSmall = $0 { return true }
            return false
        }
        #expect(bufferErrors.isEmpty)
    }

    // MARK: - validateOrThrow with specific errors

    @Test("validateOrThrow throws passphraseTooShort for short passphrase")
    func validateOrThrowPassphraseTooShort() {
        var options = SRTSocketOptions()
        options.passphrase = "short"
        #expect(throws: SRTOptionValidation.ValidationError.self) {
            try SRTOptionValidation.validateOrThrow(options)
        }
    }

    @Test("validateOrThrow throws for IP TTL out of range")
    func validateOrThrowIPTTL() {
        var options = SRTSocketOptions()
        options.ipTTL = 0
        #expect(throws: SRTOptionValidation.ValidationError.self) {
            try SRTOptionValidation.validateOrThrow(options)
        }
    }

    // MARK: - ValidationError Equatable

    @Test("Same ValidationError values are equal")
    func validationErrorEquatable() {
        let error1 = SRTOptionValidation.ValidationError.passphraseTooShort(
            length: 5, minimum: 10)
        let error2 = SRTOptionValidation.ValidationError.passphraseTooShort(
            length: 5, minimum: 10)
        #expect(error1 == error2)
    }

    @Test("Different ValidationError values are not equal")
    func validationErrorNotEqual() {
        let error1 = SRTOptionValidation.ValidationError.passphraseTooShort(
            length: 5, minimum: 10)
        let error2 = SRTOptionValidation.ValidationError.passphraseTooLong(
            length: 80, maximum: 79)
        #expect(error1 != error2)
    }
}
