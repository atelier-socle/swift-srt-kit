// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTRejectionReason Tests")
struct SRTRejectionReasonTests {
    @Test("All 18 cases exist")
    func allCasesCount() {
        #expect(SRTRejectionReason.allCases.count == 18)
    }

    @Test("Raw value for unknown is 0")
    func unknownRawValue() {
        #expect(SRTRejectionReason.unknown.rawValue == 0)
    }

    @Test("Raw value for system is 1")
    func systemRawValue() {
        #expect(SRTRejectionReason.system.rawValue == 1)
    }

    @Test("Raw value for crypto is 17")
    func cryptoRawValue() {
        #expect(SRTRejectionReason.crypto.rawValue == 17)
    }

    @Test("Raw values are sequential 0-17")
    func sequentialRawValues() {
        let rawValues = SRTRejectionReason.allCases.map(\.rawValue).sorted()
        #expect(rawValues == Array(0...17))
    }

    @Test("Init from raw value roundtrip")
    func initFromRawRoundtrip() {
        for reason in SRTRejectionReason.allCases {
            let reconstructed = SRTRejectionReason(rawValue: reason.rawValue)
            #expect(reconstructed == reason)
        }
    }

    @Test("Init from invalid raw value returns nil")
    func initFromInvalidRawValue() {
        #expect(SRTRejectionReason(rawValue: 18) == nil)
        #expect(SRTRejectionReason(rawValue: 999) == nil)
    }

    @Test("Each case has a non-empty description")
    func allCasesHaveDescriptions() {
        for reason in SRTRejectionReason.allCases {
            #expect(!reason.description.isEmpty)
        }
    }

    @Test("Unknown description")
    func unknownDescription() {
        #expect(SRTRejectionReason.unknown.description == "Unknown")
    }

    @Test("BadSecret description")
    func badSecretDescription() {
        #expect(SRTRejectionReason.badSecret.description == "Bad secret")
    }

    @Test("Timeout description")
    func timeoutDescription() {
        #expect(SRTRejectionReason.timeout.description == "Connection timeout")
    }

    @Test("Hashable conformance allows Set usage")
    func hashableConformance() {
        let set: Set<SRTRejectionReason> = [.unknown, .peer, .unknown]
        #expect(set.count == 2)
    }

    @Test("Equatable conformance")
    func equatableConformance() {
        #expect(SRTRejectionReason.peer == .peer)
        #expect(SRTRejectionReason.peer != .system)
    }
}
