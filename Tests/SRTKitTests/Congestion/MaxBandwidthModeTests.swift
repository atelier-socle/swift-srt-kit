// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("MaxBandwidthMode Tests")
struct MaxBandwidthModeTests {
    @Test("Direct mode returns exact bandwidth")
    func directExact() {
        let mode = MaxBandwidthMode.direct(bitsPerSecond: 10_000_000)
        #expect(mode.effectiveBandwidth(estimatedBW: 999) == 10_000_000)
    }

    @Test("Direct mode ignores estimatedBW")
    func directIgnoresEstimate() {
        let mode = MaxBandwidthMode.direct(bitsPerSecond: 5_000_000)
        #expect(mode.effectiveBandwidth(estimatedBW: 0) == 5_000_000)
        #expect(mode.effectiveBandwidth(estimatedBW: 100_000_000) == 5_000_000)
    }

    @Test("Relative mode: inputBW × (1 + overhead/100)")
    func relativeCalculation() {
        let mode = MaxBandwidthMode.relative(inputBW: 10_000_000, overheadPercent: 25)
        // 10_000_000 + 10_000_000 * 25 / 100 = 12_500_000
        #expect(mode.effectiveBandwidth(estimatedBW: 0) == 12_500_000)
    }

    @Test("Relative mode: 100% overhead doubles bandwidth")
    func relativeDoubles() {
        let mode = MaxBandwidthMode.relative(inputBW: 8_000_000, overheadPercent: 100)
        #expect(mode.effectiveBandwidth(estimatedBW: 0) == 16_000_000)
    }

    @Test("Relative mode: 5% overhead")
    func relativeSmallOverhead() {
        let mode = MaxBandwidthMode.relative(inputBW: 100_000_000, overheadPercent: 5)
        // 100_000_000 + 100_000_000 * 5 / 100 = 105_000_000
        #expect(mode.effectiveBandwidth(estimatedBW: 0) == 105_000_000)
    }

    @Test("Auto mode: uses estimatedBW × (1 + overhead/100)")
    func autoCalculation() {
        let mode = MaxBandwidthMode.auto(overheadPercent: 25)
        #expect(mode.effectiveBandwidth(estimatedBW: 10_000_000) == 12_500_000)
    }

    @Test("Auto mode: estimatedBW = 0 returns 0")
    func autoZeroEstimate() {
        let mode = MaxBandwidthMode.auto(overheadPercent: 25)
        #expect(mode.effectiveBandwidth(estimatedBW: 0) == 0)
    }

    @Test("Default overhead is 25%")
    func defaultOverhead() {
        #expect(MaxBandwidthMode.defaultOverheadPercent == 25)
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = MaxBandwidthMode.direct(bitsPerSecond: 1000)
        let b = MaxBandwidthMode.direct(bitsPerSecond: 1000)
        let c = MaxBandwidthMode.direct(bitsPerSecond: 2000)
        #expect(a == b)
        #expect(a != c)
    }
}
