// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("ProbeEngine Tests")
struct ProbeEngineTests {
    // MARK: - Helpers

    /// Create stats for a healthy step.
    private func goodStats(
        sendRate: UInt64 = 1_000_000,
        rtt: UInt64 = 20_000,
        rttVar: UInt64 = 3_000
    ) -> SRTStatistics {
        SRTStatistics(
            packetsSent: 100,
            packetsReceived: 100,
            packetsSentLost: 0,
            packetsReceivedLost: 0,
            rttMicroseconds: rtt,
            rttVarianceMicroseconds: rttVar,
            sendRateBitsPerSecond: sendRate
        )
    }

    /// Create stats with high loss (saturated).
    private func saturatedStats(
        sendRate: UInt64 = 1_000_000
    ) -> SRTStatistics {
        SRTStatistics(
            packetsSent: 100,
            packetsReceived: 100,
            packetsSentLost: 5,
            packetsReceivedLost: 0,
            rttMicroseconds: 20_000,
            rttVarianceMicroseconds: 5_000,
            sendRateBitsPerSecond: sendRate
        )
    }

    // MARK: - Basic flow

    @Test("Initial state is idle")
    func initialStateIdle() {
        let engine = ProbeEngine()
        #expect(engine.state == .idle)
        #expect(engine.currentStepIndex == 0)
        #expect(engine.stepMeasurements.isEmpty)
    }

    @Test("start returns sendAtBitrate for step 0")
    func startReturnsFirstStep() {
        var engine = ProbeEngine()
        let action = engine.start()
        if case .sendAtBitrate(let bps, let idx) = action {
            #expect(bps == 500_000)
            #expect(idx == 0)
        } else {
            Issue.record("Expected sendAtBitrate")
        }
        #expect(engine.state == .probing)
    }

    @Test("feedStepResult with good stats advances to next step")
    func feedGoodStatsAdvances() {
        var engine = ProbeEngine(
            configuration: ProbeConfiguration(
                steps: [1_000_000, 2_000_000, 4_000_000]))
        _ = engine.start()

        let action = engine.feedStepResult(
            statistics: goodStats(),
            stepStartTime: 0,
            currentTime: 1_000_000
        )
        if case .sendAtBitrate(let bps, let idx) = action {
            #expect(bps == 2_000_000)
            #expect(idx == 1)
        } else {
            Issue.record("Expected sendAtBitrate for step 1")
        }
    }

    @Test("feedStepResult at last step completes with result")
    func feedLastStepCompletes() {
        var engine = ProbeEngine(
            configuration: ProbeConfiguration(steps: [1_000_000]))
        _ = engine.start()

        let action = engine.feedStepResult(
            statistics: goodStats(),
            stepStartTime: 0,
            currentTime: 1_000_000
        )
        if case .complete(let result) = action {
            #expect(result.stepsCompleted == 1)
            #expect(result.achievedBandwidth == 1_000_000)
        } else {
            Issue.record("Expected complete")
        }
        #expect(engine.state == .complete)
    }

    @Test("Complete probe has all step measurements")
    func completeHasAllMeasurements() {
        var engine = ProbeEngine(
            configuration: ProbeConfiguration(
                steps: [1_000_000, 2_000_000]))
        _ = engine.start()
        _ = engine.feedStepResult(
            statistics: goodStats(),
            stepStartTime: 0, currentTime: 1_000_000)
        _ = engine.feedStepResult(
            statistics: goodStats(sendRate: 2_000_000),
            stepStartTime: 1_000_000, currentTime: 2_000_000)
        #expect(engine.stepMeasurements.count == 2)
    }

    // MARK: - Saturation detection

    @Test("High loss at step N saturates and completes")
    func highLossSaturates() {
        var engine = ProbeEngine(
            configuration: ProbeConfiguration(
                steps: [1_000_000, 2_000_000, 4_000_000, 8_000_000],
                minimumSteps: 2))
        _ = engine.start()

        _ = engine.feedStepResult(
            statistics: goodStats(),
            stepStartTime: 0, currentTime: 1_000_000)
        _ = engine.feedStepResult(
            statistics: goodStats(sendRate: 2_000_000),
            stepStartTime: 1_000_000, currentTime: 2_000_000)

        let action = engine.feedStepResult(
            statistics: saturatedStats(sendRate: 4_000_000),
            stepStartTime: 2_000_000, currentTime: 3_000_000)

        if case .complete(let result) = action {
            #expect(result.saturationStepIndex == 2)
            #expect(result.achievedBandwidth == 2_000_000)
        } else {
            Issue.record("Expected complete after saturation")
        }
    }

    @Test("RTT spike at step N saturates and completes")
    func rttSpikeSaturates() {
        var engine = ProbeEngine(
            configuration: ProbeConfiguration(
                steps: [1_000_000, 2_000_000, 4_000_000],
                rttIncreaseThreshold: 1.5,
                minimumSteps: 1))
        _ = engine.start()

        _ = engine.feedStepResult(
            statistics: goodStats(rtt: 20_000),
            stepStartTime: 0, currentTime: 1_000_000)

        let rttSpikeStats = SRTStatistics(
            packetsSent: 100, packetsReceived: 100,
            packetsSentLost: 0, packetsReceivedLost: 0,
            rttMicroseconds: 40_000,
            rttVarianceMicroseconds: 10_000,
            sendRateBitsPerSecond: 2_000_000
        )
        let action = engine.feedStepResult(
            statistics: rttSpikeStats,
            stepStartTime: 1_000_000, currentTime: 2_000_000)

        if case .complete(let result) = action {
            #expect(result.saturationStepIndex == 1)
        } else {
            Issue.record("Expected complete after RTT spike")
        }
    }

    @Test("Saturation before minimumSteps continues")
    func saturationBeforeMinStepsContinues() {
        var engine = ProbeEngine(
            configuration: ProbeConfiguration(
                steps: [1_000_000, 2_000_000, 4_000_000],
                minimumSteps: 2))
        _ = engine.start()

        let action = engine.feedStepResult(
            statistics: saturatedStats(),
            stepStartTime: 0, currentTime: 1_000_000)

        if case .sendAtBitrate(_, let idx) = action {
            #expect(idx == 1)
        } else {
            Issue.record("Expected sendAtBitrate despite early saturation")
        }
    }

    @Test("Saturation at step 3 above minimumSteps stops")
    func saturationAboveMinStepsStops() {
        var engine = ProbeEngine(
            configuration: ProbeConfiguration(
                steps: [500_000, 1_000_000, 2_000_000, 4_000_000, 8_000_000],
                minimumSteps: 2))
        _ = engine.start()

        for i in 0..<3 {
            _ = engine.feedStepResult(
                statistics: goodStats(
                    sendRate: UInt64((i + 1)) * 500_000),
                stepStartTime: UInt64(i) * 1_000_000,
                currentTime: UInt64(i + 1) * 1_000_000)
        }

        let action = engine.feedStepResult(
            statistics: saturatedStats(sendRate: 4_000_000),
            stepStartTime: 3_000_000, currentTime: 4_000_000)

        if case .complete(let result) = action {
            #expect(result.saturationStepIndex == 3)
        } else {
            Issue.record("Expected complete at step 3")
        }
    }

    // MARK: - ProbeResult

    @Test("recommendedBitrate is 70% of achieved for balanced")
    func recommendedBitrateBalanced() {
        var engine = ProbeEngine(
            configuration: ProbeConfiguration(steps: [2_000_000]))
        _ = engine.start()
        _ = engine.feedStepResult(
            statistics: goodStats(sendRate: 2_000_000),
            stepStartTime: 0, currentTime: 1_000_000)

        let result = engine.generateResult(targetQuality: .balanced)
        #expect(result != nil)
        #expect(result?.recommendedBitrate == 1_400_000)
    }

    @Test("recommendedLatency based on average RTT")
    func recommendedLatency() {
        var engine = ProbeEngine(
            configuration: ProbeConfiguration(steps: [1_000_000]))
        _ = engine.start()
        _ = engine.feedStepResult(
            statistics: goodStats(rtt: 30_000),
            stepStartTime: 0, currentTime: 1_000_000)

        let result = engine.generateResult(targetQuality: .balanced)
        #expect(result?.recommendedLatency == 120_000)
    }

    @Test("stabilityScore high for low variance")
    func stabilityScoreHigh() {
        var engine = ProbeEngine(
            configuration: ProbeConfiguration(steps: [1_000_000]))
        _ = engine.start()
        _ = engine.feedStepResult(
            statistics: goodStats(rtt: 20_000, rttVar: 1_000),
            stepStartTime: 0, currentTime: 1_000_000)

        let result = engine.generateResult()
        #expect(result?.stabilityScore == 95)
    }

    @Test("stepsCompleted matches actual steps")
    func stepsCompletedCount() {
        var engine = ProbeEngine(
            configuration: ProbeConfiguration(
                steps: [1_000_000, 2_000_000, 4_000_000]))
        _ = engine.start()
        _ = engine.feedStepResult(
            statistics: goodStats(),
            stepStartTime: 0, currentTime: 1_000_000)
        _ = engine.feedStepResult(
            statistics: goodStats(sendRate: 2_000_000),
            stepStartTime: 1_000_000, currentTime: 2_000_000)
        _ = engine.feedStepResult(
            statistics: goodStats(sendRate: 4_000_000),
            stepStartTime: 2_000_000, currentTime: 3_000_000)

        let result = engine.generateResult()
        #expect(result?.stepsCompleted == 3)
        #expect(result?.saturationStepIndex == nil)
    }
}
