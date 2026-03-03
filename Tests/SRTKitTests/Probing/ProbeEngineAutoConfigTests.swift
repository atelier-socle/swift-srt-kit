// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("ProbeEngine AutoConfig Tests")
struct ProbeEngineAutoConfigTests {
    // MARK: - Helpers

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

    private func makeResult(
        achieved: UInt64 = 10_000_000,
        rtt: UInt64 = 25_000
    ) -> ProbeResult {
        ProbeResult(
            achievedBandwidth: achieved,
            averageRTTMicroseconds: rtt,
            rttVarianceMicroseconds: 3_000,
            packetLossRate: 0.001,
            stabilityScore: 90,
            recommendedBitrate: UInt64(Double(achieved) * 0.7),
            recommendedLatency: rtt * 4,
            stepsCompleted: 5,
            totalDurationMicroseconds: 5_000_000,
            saturationStepIndex: nil
        )
    }

    // MARK: - Auto-configuration

    @Test("autoConfiguration with .quality: higher latency")
    func autoConfigQuality() {
        let result = makeResult()
        let config = ProbeEngine.autoConfiguration(
            from: result, host: "1.2.3.4", port: 9000,
            targetQuality: .quality)
        #expect(config.options.maxBandwidth == 6_000_000)
        #expect(config.options.latency == 150_000)
    }

    @Test("autoConfiguration with .lowLatency: lower latency")
    func autoConfigLowLatency() {
        let result = makeResult()
        let config = ProbeEngine.autoConfiguration(
            from: result, host: "1.2.3.4", port: 9000,
            targetQuality: .lowLatency)
        #expect(config.options.maxBandwidth == 8_000_000)
        #expect(config.options.latency == 62_500)
    }

    @Test("autoConfiguration with .balanced: middle ground")
    func autoConfigBalanced() {
        let result = makeResult()
        let config = ProbeEngine.autoConfiguration(
            from: result, host: "1.2.3.4", port: 9000,
            targetQuality: .balanced)
        #expect(config.options.maxBandwidth == 7_000_000)
        #expect(config.options.latency == 100_000)
    }

    @Test("autoConfiguration sets host and port")
    func autoConfigHostPort() {
        let result = makeResult(achieved: 5_000_000, rtt: 20_000)
        let config = ProbeEngine.autoConfiguration(
            from: result, host: "10.0.0.1", port: 4200)
        #expect(config.host == "10.0.0.1")
        #expect(config.port == 4200)
        #expect(config.mode == .caller)
    }

    // MARK: - Edge cases

    @Test("feedStepResult when idle returns failed")
    func feedWhenIdleFails() {
        var engine = ProbeEngine()
        let action = engine.feedStepResult(
            statistics: goodStats(),
            stepStartTime: 0, currentTime: 1_000_000)
        if case .failed(let reason) = action {
            #expect(reason == "Probe not started")
        } else {
            Issue.record("Expected failed")
        }
    }

    @Test("start when already probing returns failed")
    func startWhenProbingFails() {
        var engine = ProbeEngine()
        _ = engine.start()
        let action = engine.start()
        if case .failed(let reason) = action {
            #expect(reason == "Probe already in progress")
        } else {
            Issue.record("Expected failed")
        }
    }

    @Test("All steps stable completes without saturation")
    func allStepsStable() {
        var engine = ProbeEngine(
            configuration: ProbeConfiguration(
                steps: [1_000_000, 2_000_000]))
        _ = engine.start()
        _ = engine.feedStepResult(
            statistics: goodStats(),
            stepStartTime: 0, currentTime: 1_000_000)
        let action = engine.feedStepResult(
            statistics: goodStats(sendRate: 2_000_000),
            stepStartTime: 1_000_000, currentTime: 2_000_000)

        if case .complete(let result) = action {
            #expect(result.saturationStepIndex == nil)
            #expect(result.achievedBandwidth == 2_000_000)
        } else {
            Issue.record("Expected complete without saturation")
        }
    }

    @Test("generateResult returns nil when not complete")
    func generateResultNilWhenNotComplete() {
        let engine = ProbeEngine()
        #expect(engine.generateResult() == nil)
    }

    @Test("Empty steps returns failed on start")
    func emptyStepsFails() {
        var engine = ProbeEngine(
            configuration: ProbeConfiguration(steps: []))
        let action = engine.start()
        if case .failed(let reason) = action {
            #expect(reason == "No steps configured")
        } else {
            Issue.record("Expected failed for empty steps")
        }
    }
}
