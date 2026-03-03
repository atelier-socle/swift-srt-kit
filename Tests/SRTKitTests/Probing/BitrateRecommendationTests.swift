// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("BitrateRecommendation Tests")
struct BitrateRecommendationTests {
    @Test("Direction CaseIterable lists 3 values")
    func directionCases() {
        #expect(BitrateRecommendation.Direction.allCases.count == 3)
    }

    @Test("Reason CaseIterable lists 5 values")
    func reasonCases() {
        #expect(BitrateRecommendation.Reason.allCases.count == 5)
    }

    @Test("Equatable works")
    func equatable() {
        let a = BitrateRecommendation(
            recommendedBitrate: 2_000_000,
            currentBitrate: 3_000_000,
            direction: .decrease,
            reason: .packetLoss,
            confidence: 0.75
        )
        let b = BitrateRecommendation(
            recommendedBitrate: 2_000_000,
            currentBitrate: 3_000_000,
            direction: .decrease,
            reason: .packetLoss,
            confidence: 0.75
        )
        #expect(a == b)
    }

    @Test("Fields set correctly")
    func fieldsCorrect() {
        let rec = BitrateRecommendation(
            recommendedBitrate: 5_000_000,
            currentBitrate: 4_000_000,
            direction: .increase,
            reason: .bandwidthAvailable,
            confidence: 0.5
        )
        #expect(rec.recommendedBitrate == 5_000_000)
        #expect(rec.currentBitrate == 4_000_000)
        #expect(rec.direction == .increase)
        #expect(rec.reason == .bandwidthAvailable)
        #expect(rec.confidence == 0.5)
    }

    @Test("Different values are not equal")
    func notEqual() {
        let a = BitrateRecommendation(
            recommendedBitrate: 1_000_000, currentBitrate: 2_000_000,
            direction: .decrease, reason: .congestion, confidence: 0.5
        )
        let b = BitrateRecommendation(
            recommendedBitrate: 3_000_000, currentBitrate: 2_000_000,
            direction: .increase, reason: .bandwidthAvailable, confidence: 0.25
        )
        #expect(a != b)
    }
}
