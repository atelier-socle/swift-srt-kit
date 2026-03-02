// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTOptionValidation Tests")
struct SRTOptionValidationTests {
    // MARK: - Passphrase

    @Test("No passphrase is valid")
    func noPassphraseValid() {
        let options = SRTSocketOptions()
        let errors = SRTOptionValidation.validate(options)
        #expect(errors.isEmpty)
    }

    @Test("10-char passphrase is valid")
    func tenCharPassphraseValid() {
        var options = SRTSocketOptions()
        options.passphrase = "abcdefghij"
        let errors = SRTOptionValidation.validate(options)
        #expect(errors.isEmpty)
    }

    @Test("79-char passphrase is valid")
    func seventyNineCharPassphraseValid() {
        var options = SRTSocketOptions()
        options.passphrase = String(repeating: "a", count: 79)
        let errors = SRTOptionValidation.validate(options)
        #expect(errors.isEmpty)
    }

    @Test("9-char passphrase returns passphraseTooShort")
    func nineCharPassphraseTooShort() {
        var options = SRTSocketOptions()
        options.passphrase = "abcdefghi"
        let errors = SRTOptionValidation.validate(options)
        #expect(errors.count == 1)
        if case .passphraseTooShort(let length, let minimum) = errors[0] {
            #expect(length == 9)
            #expect(minimum == 10)
        } else {
            Issue.record("Expected passphraseTooShort")
        }
    }

    @Test("80-char passphrase returns passphraseTooLong")
    func eightyCharPassphraseTooLong() {
        var options = SRTSocketOptions()
        options.passphrase = String(repeating: "a", count: 80)
        let errors = SRTOptionValidation.validate(options)
        #expect(errors.count == 1)
        if case .passphraseTooLong(let length, let maximum) = errors[0] {
            #expect(length == 80)
            #expect(maximum == 79)
        } else {
            Issue.record("Expected passphraseTooLong")
        }
    }

    // MARK: - Payload size

    @Test("Default payload size 1316 is valid")
    func defaultPayloadSizeValid() {
        let options = SRTSocketOptions()
        let errors = SRTOptionValidation.validate(options)
        #expect(errors.isEmpty)
    }

    @Test("Payload size 71 returns payloadSizeOutOfRange")
    func payloadSize71OutOfRange() {
        var options = SRTSocketOptions()
        options.maxPayloadSize = 71
        let errors = SRTOptionValidation.validate(options)
        #expect(
            errors.contains(where: {
                if case .payloadSizeOutOfRange = $0 { return true }
                return false
            }))
    }

    @Test("Payload size 1501 returns payloadSizeOutOfRange")
    func payloadSize1501OutOfRange() {
        var options = SRTSocketOptions()
        options.maxPayloadSize = 1501
        let errors = SRTOptionValidation.validate(options)
        #expect(
            errors.contains(where: {
                if case .payloadSizeOutOfRange = $0 { return true }
                return false
            }))
    }

    @Test("Payload size 72 is valid (minimum)")
    func payloadSize72Valid() {
        var options = SRTSocketOptions()
        options.maxPayloadSize = 72
        let errors = SRTOptionValidation.validate(options)
        #expect(errors.isEmpty)
    }

    @Test("Payload size 1500 is valid (maximum)")
    func payloadSize1500Valid() {
        var options = SRTSocketOptions()
        options.maxPayloadSize = 1500
        let errors = SRTOptionValidation.validate(options)
        #expect(errors.isEmpty)
    }

    // MARK: - Overhead percent

    @Test("Overhead 25 is valid")
    func overhead25Valid() {
        let options = SRTSocketOptions()
        let errors = SRTOptionValidation.validate(options)
        #expect(errors.isEmpty)
    }

    @Test("Overhead 4 returns overheadPercentOutOfRange")
    func overhead4OutOfRange() {
        var options = SRTSocketOptions()
        options.overheadPercent = 4
        let errors = SRTOptionValidation.validate(options)
        #expect(
            errors.contains(where: {
                if case .overheadPercentOutOfRange = $0 { return true }
                return false
            }))
    }

    @Test("Overhead 101 returns overheadPercentOutOfRange")
    func overhead101OutOfRange() {
        var options = SRTSocketOptions()
        options.overheadPercent = 101
        let errors = SRTOptionValidation.validate(options)
        #expect(
            errors.contains(where: {
                if case .overheadPercentOutOfRange = $0 { return true }
                return false
            }))
    }

    @Test("Overhead 5 is valid (minimum)")
    func overhead5Valid() {
        var options = SRTSocketOptions()
        options.overheadPercent = 5
        let errors = SRTOptionValidation.validate(options)
        #expect(errors.isEmpty)
    }

    @Test("Overhead 100 is valid (maximum)")
    func overhead100Valid() {
        var options = SRTSocketOptions()
        options.overheadPercent = 100
        let errors = SRTOptionValidation.validate(options)
        #expect(errors.isEmpty)
    }

    // MARK: - Buffer sizes

    @Test("Send buffer size 0 returns bufferSizeTooSmall")
    func sendBufferZeroError() {
        var options = SRTSocketOptions()
        options.sendBufferSize = 0
        let errors = SRTOptionValidation.validate(options)
        #expect(
            errors.contains(where: {
                if case .bufferSizeTooSmall(let name, _, _) = $0 {
                    return name == "sendBuffer"
                }
                return false
            }))
    }

    // MARK: - Key rotation

    @Test("preAnnounce > refreshRate returns error")
    func preAnnounceExceedsRefreshRate() {
        var options = SRTSocketOptions()
        options.kmPreAnnounce = 1000
        options.kmRefreshRate = 500
        let errors = SRTOptionValidation.validate(options)
        #expect(
            errors.contains(where: {
                if case .kmPreAnnounceExceedsRefreshRate = $0 { return true }
                return false
            }))
    }

    // MARK: - Multiple errors

    @Test("Multiple invalid fields return multiple errors")
    func multipleErrors() {
        var options = SRTSocketOptions()
        options.passphrase = "short"
        options.maxPayloadSize = 10
        options.overheadPercent = 200
        let errors = SRTOptionValidation.validate(options)
        #expect(errors.count >= 3)
    }

    // MARK: - validateOrThrow

    @Test("validateOrThrow succeeds for valid options")
    func validateOrThrowValid() throws {
        let options = SRTSocketOptions()
        try SRTOptionValidation.validateOrThrow(options)
    }

    @Test("validateOrThrow throws for invalid options")
    func validateOrThrowInvalid() {
        var options = SRTSocketOptions()
        options.maxPayloadSize = 10
        #expect(throws: SRTOptionValidation.ValidationError.self) {
            try SRTOptionValidation.validateOrThrow(options)
        }
    }

    // MARK: - Error descriptions

    @Test("All ValidationError cases have non-empty descriptions")
    func errorDescriptions() {
        let errors: [SRTOptionValidation.ValidationError] = [
            .passphraseTooShort(length: 5, minimum: 10),
            .passphraseTooLong(length: 80, maximum: 79),
            .payloadSizeOutOfRange(got: 10, range: 72...1500),
            .overheadPercentOutOfRange(got: 200, range: 5...100),
            .bufferSizeTooSmall(name: "test", got: 0, minimum: 1),
            .latencyNegative,
            .ipTTLOutOfRange(got: 0, range: 1...255),
            .ipTOSOutOfRange(got: 256, range: 0...255),
            .kmPreAnnounceExceedsRefreshRate(preAnnounce: 100, refreshRate: 50)
        ]
        for error in errors {
            #expect(!error.description.isEmpty)
        }
    }
}
