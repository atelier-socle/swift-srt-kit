// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("CongestionDecision Tests")
struct CongestionDecisionTests {
    @Test("noChange: all fields nil, shouldDrop false")
    func noChange() {
        let d = CongestionDecision.noChange
        #expect(d.congestionWindow == nil)
        #expect(d.sendingPeriodMicroseconds == nil)
        #expect(!d.shouldDrop)
        #expect(d.maxSendRateBps == nil)
    }

    @Test("drop: shouldDrop true")
    func drop() {
        let d = CongestionDecision.drop
        #expect(d.shouldDrop)
    }

    @Test("Custom init sets all fields")
    func customInit() {
        let d = CongestionDecision(
            congestionWindow: 256,
            sendingPeriodMicroseconds: 100,
            shouldDrop: false,
            maxSendRateBps: 5_000_000)
        #expect(d.congestionWindow == 256)
        #expect(d.sendingPeriodMicroseconds == 100)
        #expect(!d.shouldDrop)
        #expect(d.maxSendRateBps == 5_000_000)
    }

    @Test("Equatable works")
    func equatable() {
        let a = CongestionDecision(congestionWindow: 100)
        let b = CongestionDecision(congestionWindow: 100)
        let c = CongestionDecision(congestionWindow: 200)
        #expect(a == b)
        #expect(a != c)
    }

    @Test("nil fields mean no change")
    func nilFieldsNoChange() {
        let d = CongestionDecision()
        #expect(d == CongestionDecision.noChange)
    }
}
