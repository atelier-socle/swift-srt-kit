// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("BitrateMonitorConfiguration Tests")
struct BitrateMonitorConfigurationTests {
    @Test("Default values correct")
    func defaultValues() {
        let config = BitrateMonitorConfiguration()
        #expect(config.hysteresisCount == 3)
        #expect(config.lossThreshold == 0.02)
        #expect(config.rttIncreaseRatio == 1.3)
        #expect(config.bufferThreshold == 0.7)
        #expect(config.headroomRatio == 0.7)
        #expect(config.stepDownFactor == 0.75)
        #expect(config.stepUpFactor == 1.10)
        #expect(config.minimumBitrate == 100_000)
        #expect(config.maximumBitrate == 0)
    }

    @Test("Conservative preset: higher hysteresis")
    func conservativePreset() {
        let config = BitrateMonitorConfiguration.conservative
        #expect(config.hysteresisCount == 5)
        #expect(config.stepDownFactor == 0.85)
        #expect(config.stepUpFactor == 1.05)
    }

    @Test("Responsive preset: lower hysteresis")
    func responsivePreset() {
        let config = BitrateMonitorConfiguration.responsive
        #expect(config.hysteresisCount == 2)
        #expect(config.stepDownFactor == 0.70)
    }

    @Test("Aggressive preset: hysteresis = 1")
    func aggressivePreset() {
        let config = BitrateMonitorConfiguration.aggressive
        #expect(config.hysteresisCount == 1)
        #expect(config.stepDownFactor == 0.60)
        #expect(config.stepUpFactor == 1.20)
    }

    @Test("Equatable works")
    func equatable() {
        let a = BitrateMonitorConfiguration()
        let b = BitrateMonitorConfiguration()
        #expect(a == b)
        #expect(
            BitrateMonitorConfiguration.conservative
                != BitrateMonitorConfiguration.aggressive)
    }
}
