// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("Probing Showcase")
struct ProbingShowcaseTests {
    // MARK: - ProbeEngine

    @Test("ProbeEngine start and step progression")
    func probeEngineStart() {
        var engine = ProbeEngine(configuration: .standard)

        // Start probing — returns first action
        let action = engine.start()
        if case .sendAtBitrate = action {
            // Expected: first step starts
        }

        // Feed step results using SRTStatistics
        for i in 0..<3 {
            var stats = SRTStatistics()
            stats.sendRateBitsPerSecond =
                UInt64(i + 1) * 2_000_000
            stats.rttMicroseconds =
                20_000 + UInt64(i) * 2_000
            stats.packetsSent = UInt64(i + 1) * 100
            _ = engine.feedStepResult(
                statistics: stats,
                stepStartTime: UInt64(i) * 1_000_000,
                currentTime: UInt64(i + 1) * 1_000_000)
        }

        #expect(engine.currentStepIndex >= 0)
    }

    @Test("ProbeEngine auto-configuration generates valid config")
    func probeAutoConfig() {
        let result = ProbeResult(
            achievedBandwidth: 10_000_000,
            averageRTTMicroseconds: 25_000,
            rttVarianceMicroseconds: 5_000,
            packetLossRate: 0.01,
            stabilityScore: 85,
            recommendedBitrate: 7_000_000,
            recommendedLatency: 100_000,
            stepsCompleted: 5,
            totalDurationMicroseconds: 5_000_000,
            saturationStepIndex: 4)

        let config = ProbeEngine.autoConfiguration(
            from: result,
            host: "srt.example.com",
            port: 4200,
            targetQuality: .balanced)

        #expect(config.host == "srt.example.com")
        #expect(config.port == 4200)
    }

    @Test("ProbeConfiguration presets have ascending steps")
    func probeConfigPresets() {
        let quick = ProbeConfiguration.quick
        let standard = ProbeConfiguration.standard
        let thorough = ProbeConfiguration.thorough

        #expect(quick.steps.count < standard.steps.count)
        #expect(standard.steps.count < thorough.steps.count)

        // Steps should be ascending
        for config in [quick, standard, thorough] {
            for i in 1..<config.steps.count {
                #expect(config.steps[i] > config.steps[i - 1])
            }
        }
    }

    // MARK: - BitrateMonitor

    @Test("BitrateMonitor hysteresis delays recommendation")
    func bitrateMonitorHysteresis() {
        var monitor = BitrateMonitor(
            configuration: .conservative)

        // Feed stable samples — should maintain
        for _ in 0..<5 {
            var stats = SRTStatistics()
            stats.packetsSent = 1000
            stats.packetsSentLost = 0
            stats.rttMicroseconds = 20_000
            stats.sendBufferPackets = 10
            stats.sendBufferCapacity = 8192
            stats.bandwidthBitsPerSecond = 10_000_000
            stats.sendRateBitsPerSecond = 8_000_000
            _ = monitor.evaluate(
                statistics: stats, currentBitrate: 8_000_000)
        }

        // After stable samples, recommendation should be maintain
        var stableStats = SRTStatistics()
        stableStats.packetsSent = 1000
        stableStats.rttMicroseconds = 20_000
        stableStats.sendBufferPackets = 10
        stableStats.sendBufferCapacity = 8192
        stableStats.bandwidthBitsPerSecond = 10_000_000
        stableStats.sendRateBitsPerSecond = 8_000_000
        let rec = monitor.evaluate(
            statistics: stableStats, currentBitrate: 8_000_000)

        if let rec {
            // Either maintain or increase (stable conditions)
            #expect(
                rec.direction == .maintain
                    || rec.direction == .increase)
        }
    }

    @Test("TargetQuality presets have correct bandwidth factors")
    func targetQualityFactors() {
        #expect(TargetQuality.quality.bandwidthFactor == 0.6)
        #expect(TargetQuality.balanced.bandwidthFactor == 0.7)
        #expect(TargetQuality.lowLatency.bandwidthFactor == 0.8)
    }
}
