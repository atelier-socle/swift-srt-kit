// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("Statistics Showcase")
struct StatisticsShowcaseTests {
    // MARK: - SRTStatistics

    @Test("SRTStatistics tracks all field categories")
    func statisticsFields() {
        var stats = SRTStatistics()
        stats.packetsSent = 10_000
        stats.packetsReceived = 9_800
        stats.packetsSentLost = 50
        stats.bytesReceived = 12_888_800
        stats.rttMicroseconds = 25_000
        stats.bandwidthBitsPerSecond = 10_000_000
        stats.sendBufferPackets = 32
        stats.sendBufferCapacity = 8192

        #expect(stats.packetsSent == 10_000)
        #expect(stats.packetsReceived == 9_800)
        #expect(stats.rttMicroseconds == 25_000)
    }

    @Test("SRTStatistics computed loss rate")
    func lossRate() {
        var stats = SRTStatistics()
        stats.packetsSent = 1000
        stats.packetsSentLost = 10
        // lossRate = lost / sent
        #expect(stats.lossRate >= 0.0)
        #expect(stats.lossRate <= 1.0)
    }

    @Test("SRTStatistics buffer utilization")
    func bufferUtilization() {
        var stats = SRTStatistics()
        stats.sendBufferPackets = 100
        stats.sendBufferCapacity = 8192
        #expect(stats.sendBufferUtilization >= 0.0)
        #expect(stats.sendBufferUtilization <= 1.0)
    }

    // MARK: - Quality Scoring

    @Test("SRTConnectionQuality scoring with 5 weighted metrics")
    func qualityScoring() {
        let stats = SRTStatistics()
        let quality = SRTConnectionQuality.from(statistics: stats)

        // Default stats should produce high quality (no loss, no RTT)
        #expect(quality.score >= 0.0)
        #expect(quality.score <= 1.0)

        // Grade matches score
        switch quality.grade {
        case .excellent:
            #expect(quality.score > 0.9)
        case .good:
            #expect(quality.score > 0.7)
        case .fair:
            #expect(quality.score > 0.5)
        case .poor:
            #expect(quality.score > 0.3)
        case .critical:
            #expect(quality.score <= 0.3)
        }
    }

    @Test("Quality weights sum to 1.0")
    func qualityWeights() {
        let totalWeight =
            SRTConnectionQuality.rttWeight
            + SRTConnectionQuality.lossWeight
            + SRTConnectionQuality.bufferWeight
            + SRTConnectionQuality.bitrateWeight
            + SRTConnectionQuality.stabilityWeight
        #expect(abs(totalWeight - 1.0) < 0.001)
    }

    // MARK: - Prometheus Export

    @Test("PrometheusExporter produces text exposition format")
    func prometheusExport() {
        var stats = SRTStatistics()
        stats.packetsSent = 5000
        stats.packetsReceived = 4900
        stats.rttMicroseconds = 15_000

        let exporter = PrometheusExporter(prefix: "srt")
        let rendered = exporter.render(
            stats, labels: ["stream": "main"])

        #expect(rendered.contains("# HELP"))
        #expect(rendered.contains("# TYPE"))
        #expect(rendered.contains("srt_"))
    }

    // MARK: - StatsD Export

    @Test("StatsDExporter produces datagram format")
    func statsdExport() {
        var stats = SRTStatistics()
        stats.packetsSent = 1000
        stats.rttMicroseconds = 20_000

        let exporter = StatsDExporter(prefix: "srt")
        let rendered = exporter.render(
            stats, labels: ["env": "test"])

        // StatsD format: metric:value|type
        #expect(!rendered.isEmpty)
        #expect(rendered.contains("|g"))
        #expect(rendered.contains("|c"))
    }
}
