// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("QualityRecommendation Tests")
struct QualityRecommendationTests {
    private func makeMetrics(
        score: Double,
        statistics: SRTStatistics = SRTStatistics(),
        rttScore: Double = 1.0,
        lossScore: Double = 1.0,
        stabilityScore: Double = 1.0,
        bitrateEff: Double = 0.5,
        bufferScore: Double = 1.0
    ) -> QualityMetrics {
        QualityMetrics(
            score: score,
            statistics: statistics,
            rttScore: rttScore,
            lossScore: lossScore,
            stabilityScore: stabilityScore,
            bitrateEff: bitrateEff,
            bufferScore: bufferScore
        )
    }

    @Test("Excellent stats return nil")
    func excellentNil() {
        let metrics = makeMetrics(score: 0.95)
        let result = QualityRecommendation.generate(from: metrics)
        #expect(result == nil)
    }

    @Test("Low score + high loss recommends bitrate/latency")
    func lowScoreHighLoss() {
        let stats = SRTStatistics(
            packetsSent: 100,
            packetsReceived: 100,
            packetsSentLost: 15
        )
        let metrics = makeMetrics(
            score: 0.2, statistics: stats, lossScore: 0.0,
            stabilityScore: 0.5, bitrateEff: 0.5, bufferScore: 0.5)
        let result = QualityRecommendation.generate(from: metrics)
        #expect(result != nil)
        #expect(result?.contains("bitrate") == true)
    }

    @Test("Low score + high RTT recommends latency")
    func lowScoreHighRTT() {
        let stats = SRTStatistics(rttMicroseconds: 300_000)
        let metrics = makeMetrics(
            score: 0.4, statistics: stats, lossScore: 0.8,
            stabilityScore: 0.5, bitrateEff: 0.5, bufferScore: 0.5)
        let result = QualityRecommendation.generate(from: metrics)
        #expect(result != nil)
        #expect(result?.contains("latency") == true)
    }

    @Test("Low score + low buffer recommends buffer size")
    func lowScoreLowBuffer() {
        let metrics = makeMetrics(
            score: 0.6, lossScore: 0.8,
            stabilityScore: 0.8, bitrateEff: 0.5, bufferScore: 0.2)
        let result = QualityRecommendation.generate(from: metrics)
        #expect(result != nil)
        #expect(result?.contains("buffer") == true)
    }

    @Test("High bitrate efficiency recommends reducing bitrate")
    func highBitrateEff() {
        let metrics = makeMetrics(
            score: 0.8, lossScore: 0.9,
            stabilityScore: 0.9, bitrateEff: 0.96, bufferScore: 0.9)
        let result = QualityRecommendation.generate(from: metrics)
        #expect(result != nil)
        #expect(result?.contains("bandwidth") == true || result?.contains("capacity") == true)
    }

    @Test("Low stability recommends FEC")
    func lowStability() {
        let metrics = makeMetrics(
            score: 0.8, lossScore: 0.9,
            stabilityScore: 0.3, bitrateEff: 0.5, bufferScore: 0.9)
        let result = QualityRecommendation.generate(from: metrics)
        #expect(result != nil)
        #expect(result?.contains("FEC") == true)
    }

    @Test("First matching rule wins (priority order)")
    func firstRuleWins() {
        let stats = SRTStatistics(
            packetsSent: 100,
            packetsReceived: 100,
            packetsSentLost: 15,
            rttMicroseconds: 300_000
        )
        let metrics = makeMetrics(
            score: 0.2, statistics: stats, lossScore: 0.0,
            stabilityScore: 0.3, bitrateEff: 0.5, bufferScore: 0.5)
        let result = QualityRecommendation.generate(from: metrics)
        #expect(result?.contains("bitrate") == true)
    }

    @Test("Edge case: exactly at score threshold 0.3")
    func edgeCaseThreshold() {
        let metrics = makeMetrics(
            score: 0.3, lossScore: 0.5,
            stabilityScore: 0.8, bitrateEff: 0.5, bufferScore: 0.8)
        let result = QualityRecommendation.generate(from: metrics)
        #expect(result == nil || result?.contains("Reduce bitrate significantly") == false)
    }

    @Test("Mid-range score with no specific issue returns nil")
    func midRangeNoIssue() {
        let stats = SRTStatistics(rttMicroseconds: 50000)
        let metrics = makeMetrics(
            score: 0.75, statistics: stats, lossScore: 0.8,
            stabilityScore: 0.7, bitrateEff: 0.5, bufferScore: 0.8)
        let result = QualityRecommendation.generate(from: metrics)
        #expect(result == nil)
    }
}
