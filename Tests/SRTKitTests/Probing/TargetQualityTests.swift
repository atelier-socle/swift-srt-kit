// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("TargetQuality Tests")
struct TargetQualityTests {
    @Test(".quality bandwidthFactor = 0.6")
    func qualityBandwidthFactor() {
        #expect(TargetQuality.quality.bandwidthFactor == 0.6)
    }

    @Test(".balanced bandwidthFactor = 0.7")
    func balancedBandwidthFactor() {
        #expect(TargetQuality.balanced.bandwidthFactor == 0.7)
    }

    @Test(".lowLatency bandwidthFactor = 0.8")
    func lowLatencyBandwidthFactor() {
        #expect(TargetQuality.lowLatency.bandwidthFactor == 0.8)
    }

    @Test("CaseIterable lists all 3")
    func caseIterable() {
        #expect(TargetQuality.allCases.count == 3)
    }

    @Test("All have non-empty description")
    func descriptions() {
        for quality in TargetQuality.allCases {
            #expect(!quality.description.isEmpty)
        }
    }

    @Test("Latency multipliers are ordered")
    func latencyMultiplierOrder() {
        #expect(
            TargetQuality.quality.latencyMultiplier
                > TargetQuality.balanced.latencyMultiplier)
        #expect(
            TargetQuality.balanced.latencyMultiplier
                > TargetQuality.lowLatency.latencyMultiplier)
    }
}
