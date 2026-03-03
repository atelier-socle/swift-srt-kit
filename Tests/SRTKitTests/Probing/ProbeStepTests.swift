// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("ProbeStep Tests")
struct ProbeStepTests {
    @Test("init stores all properties")
    func initStoresProperties() {
        let step = ProbeStep(
            targetBitrate: 5_000_000,
            durationMicroseconds: 1_000_000,
            index: 3
        )
        #expect(step.targetBitrate == 5_000_000)
        #expect(step.durationMicroseconds == 1_000_000)
        #expect(step.index == 3)
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = ProbeStep(targetBitrate: 1000, durationMicroseconds: 500, index: 0)
        let b = ProbeStep(targetBitrate: 1000, durationMicroseconds: 500, index: 0)
        let c = ProbeStep(targetBitrate: 2000, durationMicroseconds: 500, index: 0)
        #expect(a == b)
        #expect(a != c)
    }
}
