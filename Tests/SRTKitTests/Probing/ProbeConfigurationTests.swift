// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("ProbeConfiguration Tests")
struct ProbeConfigurationTests {
    @Test("Default steps are ascending")
    func defaultStepsAscending() {
        let config = ProbeConfiguration()
        for i in 1..<config.steps.count {
            #expect(config.steps[i] > config.steps[i - 1])
        }
    }

    @Test("Standard preset values correct")
    func standardPreset() {
        let config = ProbeConfiguration.standard
        #expect(config.steps.count == 7)
        #expect(config.stepDurationMicroseconds == 1_000_000)
        #expect(config.lossThreshold == 0.02)
        #expect(config.rttIncreaseThreshold == 1.5)
        #expect(config.minimumSteps == 2)
    }

    @Test("Quick preset: 3 steps, 500ms")
    func quickPreset() {
        let config = ProbeConfiguration.quick
        #expect(config.steps.count == 3)
        #expect(config.stepDurationMicroseconds == 500_000)
    }

    @Test("Thorough preset: 10 steps, 2s")
    func thoroughPreset() {
        let config = ProbeConfiguration.thorough
        #expect(config.steps.count == 10)
        #expect(config.stepDurationMicroseconds == 2_000_000)
    }

    @Test("Equatable works")
    func equatable() {
        let a = ProbeConfiguration.standard
        let b = ProbeConfiguration.standard
        #expect(a == b)
        #expect(ProbeConfiguration.standard != ProbeConfiguration.quick)
    }

    @Test("Custom init overrides defaults")
    func customInit() {
        let config = ProbeConfiguration(
            steps: [1_000_000, 5_000_000],
            stepDurationMicroseconds: 2_000_000,
            lossThreshold: 0.05,
            rttIncreaseThreshold: 2.0,
            minimumSteps: 1
        )
        #expect(config.steps.count == 2)
        #expect(config.stepDurationMicroseconds == 2_000_000)
        #expect(config.lossThreshold == 0.05)
        #expect(config.rttIncreaseThreshold == 2.0)
        #expect(config.minimumSteps == 1)
    }
}
