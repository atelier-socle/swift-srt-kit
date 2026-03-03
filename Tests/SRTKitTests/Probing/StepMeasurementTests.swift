// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("StepMeasurement Tests")
struct StepMeasurementTests {
    @Test("Fields set correctly from init")
    func fieldsSetCorrectly() {
        let m = StepMeasurement(
            targetBitrate: 4_000_000,
            achievedSendRate: 3_800_000,
            rttMicroseconds: 25_000,
            rttVarianceMicroseconds: 5_000,
            lossRate: 0.01,
            bufferUtilization: 0.3,
            saturated: false,
            stepIndex: 2
        )
        #expect(m.targetBitrate == 4_000_000)
        #expect(m.achievedSendRate == 3_800_000)
        #expect(m.rttMicroseconds == 25_000)
        #expect(m.rttVarianceMicroseconds == 5_000)
        #expect(m.lossRate == 0.01)
        #expect(m.bufferUtilization == 0.3)
        #expect(!m.saturated)
        #expect(m.stepIndex == 2)
    }

    @Test("Equatable works")
    func equatable() {
        let a = StepMeasurement(
            targetBitrate: 1_000_000, achievedSendRate: 900_000,
            rttMicroseconds: 10_000, rttVarianceMicroseconds: 2_000,
            lossRate: 0.0, bufferUtilization: 0.1,
            saturated: false, stepIndex: 0
        )
        let b = StepMeasurement(
            targetBitrate: 1_000_000, achievedSendRate: 900_000,
            rttMicroseconds: 10_000, rttVarianceMicroseconds: 2_000,
            lossRate: 0.0, bufferUtilization: 0.1,
            saturated: false, stepIndex: 0
        )
        #expect(a == b)
    }

    @Test("Saturated flag reflects detection")
    func saturatedFlag() {
        let saturated = StepMeasurement(
            targetBitrate: 8_000_000, achievedSendRate: 5_000_000,
            rttMicroseconds: 50_000, rttVarianceMicroseconds: 20_000,
            lossRate: 0.05, bufferUtilization: 0.8,
            saturated: true, stepIndex: 3
        )
        #expect(saturated.saturated)
    }
}
