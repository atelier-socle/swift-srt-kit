// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit
@testable import SRTKitCommands

@Suite("ProbeResultFormatter Tests")
struct ProbeResultFormatterTests {
    private func sampleResult() -> ProbeResult {
        ProbeResult(
            achievedBandwidth: 8_000_000,
            averageRTTMicroseconds: 25_000,
            rttVarianceMicroseconds: 5_000,
            packetLossRate: 0.01,
            stabilityScore: 85,
            recommendedBitrate: 5_600_000,
            recommendedLatency: 100_000,
            stepsCompleted: 5,
            totalDurationMicroseconds: 5_000_000,
            saturationStepIndex: 4)
    }

    // MARK: - format

    @Test("Result produces non-empty output")
    func formatNonEmpty() {
        let output = ProbeResultFormatter.format(sampleResult())
        #expect(!output.isEmpty)
    }

    @Test("Output contains achieved bandwidth")
    func formatContainsBandwidth() {
        let output = ProbeResultFormatter.format(sampleResult())
        #expect(output.contains("Achieved bandwidth"))
    }

    @Test("Output contains recommended bitrate")
    func formatContainsRecommended() {
        let output = ProbeResultFormatter.format(sampleResult())
        #expect(output.contains("Recommended bitrate"))
    }

    @Test("Output contains stability score")
    func formatContainsStability() {
        let output = ProbeResultFormatter.format(sampleResult())
        #expect(output.contains("85"))
    }

    // MARK: - formatSteps

    @Test("Empty steps returns empty")
    func formatStepsEmpty() {
        let output = ProbeResultFormatter.formatSteps([])
        #expect(output.isEmpty)
    }

    @Test("3 steps produce 3 data rows")
    func formatStepsThreeRows() {
        var steps: [StepMeasurement] = []
        for i in 0..<3 {
            let step = StepMeasurement(
                targetBitrate: UInt64(i + 1) * 1_000_000,
                achievedSendRate: UInt64(i + 1) * 900_000,
                rttMicroseconds: 20_000,
                rttVarianceMicroseconds: 3_000,
                lossRate: 0.005,
                bufferUtilization: 0.3,
                saturated: i == 2,
                stepIndex: i)
            steps.append(step)
        }
        let output = ProbeResultFormatter.formatSteps(steps)
        let lines = output.split(separator: "\n")
        // 2 header lines + 3 data rows
        #expect(lines.count == 5)
    }

    // MARK: - formatRecommendations

    @Test("Contains target quality name")
    func recommendationsContainsQuality() {
        let output = ProbeResultFormatter.formatRecommendations(
            sampleResult(), targetQuality: .balanced)
        #expect(output.contains("balanced"))
    }

    @Test("Contains recommended latency")
    func recommendationsContainsLatency() {
        let output = ProbeResultFormatter.formatRecommendations(
            sampleResult(), targetQuality: .quality)
        #expect(output.contains("Recommended latency"))
    }
}
