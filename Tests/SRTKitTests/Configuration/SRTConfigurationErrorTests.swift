// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTConfigurationError Tests")
struct SRTConfigurationErrorTests {
    @Test("Each error case has non-empty description")
    func allDescriptionsNonEmpty() {
        let errors: [SRTConfigurationError] = [
            .validationFailed(errors: [
                .passphraseTooShort(length: 5, minimum: 10)
            ]),
            .emptyHost,
            .portOutOfRange(got: 0),
            .callerRequiresHost,
            .listenerRequiresPort
        ]
        for error in errors {
            #expect(!error.description.isEmpty)
        }
    }

    @Test("Equatable works for simple cases")
    func equatableSimpleCases() {
        #expect(
            SRTConfigurationError.emptyHost == SRTConfigurationError.emptyHost)
        #expect(
            SRTConfigurationError.callerRequiresHost
                == SRTConfigurationError.callerRequiresHost)
    }

    @Test("Equatable works for associated values")
    func equatableAssociatedValues() {
        #expect(
            SRTConfigurationError.portOutOfRange(got: 0)
                == SRTConfigurationError.portOutOfRange(got: 0))
        #expect(
            SRTConfigurationError.portOutOfRange(got: 0)
                != SRTConfigurationError.portOutOfRange(got: -1))
    }

    @Test("validationFailed includes inner errors in description")
    func validationFailedDescription() {
        let inner: [SRTOptionValidation.ValidationError] = [
            .passphraseTooShort(length: 5, minimum: 10),
            .payloadSizeOutOfRange(got: 10, range: 72...1500)
        ]
        let error = SRTConfigurationError.validationFailed(errors: inner)
        let desc = error.description
        #expect(desc.contains("Passphrase"))
        #expect(desc.contains("Payload"))
    }

    @Test("Different error cases are not equal")
    func differentCasesNotEqual() {
        #expect(
            SRTConfigurationError.emptyHost
                != SRTConfigurationError.callerRequiresHost)
    }
}
