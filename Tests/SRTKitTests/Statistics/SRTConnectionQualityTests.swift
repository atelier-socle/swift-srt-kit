// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTConnectionQuality Tests")
struct SRTConnectionQualityTests {
    // MARK: - Score calculation

    @Test("Perfect stats produce excellent grade")
    func perfectStatsExcellent() {
        let stats = SRTStatistics(
            packetsSent: 10000,
            packetsReceived: 10000,
            rttMicroseconds: 5000,
            rttVarianceMicroseconds: 500,
            sendRateBitsPerSecond: 4_000_000,
            maxBandwidthBitsPerSecond: 5_000_000,
            sendBufferPackets: 10,
            sendBufferCapacity: 8192
        )
        let quality = SRTConnectionQuality.from(statistics: stats)
        #expect(quality.score > 0.9)
        #expect(quality.grade == .excellent)
    }

    @Test("High loss produces low overall score")
    func highLossLowScore() {
        let stats = SRTStatistics(
            packetsSent: 100,
            packetsReceived: 100,
            packetsSentLost: 10,
            packetsReceivedLost: 10
        )
        let quality = SRTConnectionQuality.from(statistics: stats)
        #expect(quality.lossScore == 0)
    }

    @Test("High RTT (500ms) produces rttScore of 0")
    func highRTTZeroScore() {
        let stats = SRTStatistics(rttMicroseconds: 500_000)
        let quality = SRTConnectionQuality.from(statistics: stats)
        #expect(quality.rttScore == 0)
    }

    @Test("Full send buffer produces low bufferScore")
    func fullBufferLowScore() {
        let stats = SRTStatistics(
            sendBufferPackets: 8192,
            sendBufferCapacity: 8192
        )
        let quality = SRTConnectionQuality.from(statistics: stats)
        #expect(quality.bufferScore == 0)
    }

    @Test("RTT variance equal to RTT produces stabilityScore of 0")
    func varianceEqualRTTZeroStability() {
        let stats = SRTStatistics(
            rttMicroseconds: 50000,
            rttVarianceMicroseconds: 50000
        )
        let quality = SRTConnectionQuality.from(statistics: stats)
        #expect(quality.stabilityScore == 0)
    }

    @Test("Zero RTT produces rttScore of 1.0")
    func zeroRTTFullScore() {
        let stats = SRTStatistics(rttMicroseconds: 0)
        let quality = SRTConnectionQuality.from(statistics: stats)
        #expect(quality.rttScore == 1.0)
    }

    @Test("Zero maxBandwidth produces bitrateEff of 0.5")
    func zeroBandwidthNeutral() {
        let stats = SRTStatistics(maxBandwidthBitsPerSecond: 0)
        let quality = SRTConnectionQuality.from(statistics: stats)
        #expect(quality.bitrateEfficiencyScore == 0.5)
    }

    // MARK: - Grade thresholds

    @Test("Grade excellent for score > 0.9")
    func gradeExcellent() {
        let stats = SRTStatistics(
            packetsSent: 10000,
            packetsReceived: 10000,
            rttMicroseconds: 5000,
            rttVarianceMicroseconds: 500,
            sendRateBitsPerSecond: 4_000_000,
            maxBandwidthBitsPerSecond: 5_000_000,
            sendBufferPackets: 10,
            sendBufferCapacity: 8192
        )
        let quality = SRTConnectionQuality.from(statistics: stats)
        #expect(quality.grade == .excellent)
    }

    @Test("Grade critical for very bad stats")
    func gradeCritical() {
        let stats = SRTStatistics(
            packetsSent: 100,
            packetsReceived: 100,
            packetsSentLost: 20,
            rttMicroseconds: 600_000,
            rttVarianceMicroseconds: 600_000,
            sendBufferPackets: 8192,
            sendBufferCapacity: 8192
        )
        let quality = SRTConnectionQuality.from(statistics: stats)
        #expect(quality.grade == .critical)
    }

    // MARK: - Grade Comparable

    @Test("Grade: excellent > critical")
    func gradeComparableExcellentCritical() {
        #expect(SRTConnectionQuality.Grade.excellent > .critical)
    }

    @Test("Grade: good > fair")
    func gradeComparableGoodFair() {
        #expect(SRTConnectionQuality.Grade.good > .fair)
    }

    @Test("Grade sorting works correctly")
    func gradeSorting() {
        let grades: [SRTConnectionQuality.Grade] = [
            .excellent, .critical, .good, .poor, .fair
        ]
        let sorted = grades.sorted()
        #expect(sorted == [.critical, .poor, .fair, .good, .excellent])
    }

    @Test("Grade CaseIterable has 5 cases")
    func gradeCaseIterable() {
        #expect(SRTConnectionQuality.Grade.allCases.count == 5)
    }

    @Test("Grade description matches rawValue")
    func gradeDescription() {
        #expect(SRTConnectionQuality.Grade.excellent.description == "excellent")
        #expect(SRTConnectionQuality.Grade.critical.description == "critical")
    }

    // MARK: - Recommendations

    @Test("Excellent stats produce nil recommendation")
    func excellentNilRecommendation() {
        let stats = SRTStatistics(
            packetsSent: 10000,
            packetsReceived: 10000,
            rttMicroseconds: 5000,
            rttVarianceMicroseconds: 500,
            sendRateBitsPerSecond: 4_000_000,
            maxBandwidthBitsPerSecond: 5_000_000,
            sendBufferPackets: 10,
            sendBufferCapacity: 8192
        )
        let quality = SRTConnectionQuality.from(statistics: stats)
        #expect(quality.recommendation == nil)
    }

    @Test("High loss + low score recommends bitrate/latency")
    func highLossRecommendation() {
        let stats = SRTStatistics(
            packetsSent: 100,
            packetsReceived: 100,
            packetsSentLost: 20,
            rttMicroseconds: 400_000,
            rttVarianceMicroseconds: 400_000,
            sendBufferPackets: 8000,
            sendBufferCapacity: 8192
        )
        let quality = SRTConnectionQuality.from(statistics: stats)
        #expect(quality.recommendation != nil)
        #expect(quality.recommendation?.contains("bitrate") == true || quality.recommendation?.contains("latency") == true)
    }

    @Test("High bitrate efficiency recommends reducing bitrate")
    func highBitrateEffRecommendation() {
        let stats = SRTStatistics(
            packetsSent: 10000,
            packetsReceived: 10000,
            rttMicroseconds: 5000,
            rttVarianceMicroseconds: 500,
            sendRateBitsPerSecond: 4_900_000,
            maxBandwidthBitsPerSecond: 5_000_000,
            sendBufferPackets: 100,
            sendBufferCapacity: 8192
        )
        let quality = SRTConnectionQuality.from(statistics: stats)
        #expect(quality.recommendation?.contains("capacity") == true || quality.recommendation?.contains("bandwidth") == true)
    }

    @Test("Low stability recommends FEC")
    func lowStabilityRecommendation() {
        let stats = SRTStatistics(
            packetsSent: 10000,
            packetsReceived: 10000,
            rttMicroseconds: 100_000,
            rttVarianceMicroseconds: 80000,
            sendRateBitsPerSecond: 2_000_000,
            maxBandwidthBitsPerSecond: 5_000_000,
            sendBufferPackets: 100,
            sendBufferCapacity: 8192
        )
        let quality = SRTConnectionQuality.from(statistics: stats)
        #expect(quality.recommendation?.contains("FEC") == true || quality.recommendation?.contains("unstable") == true)
    }

    // MARK: - Weights

    @Test("All weights sum to 1.0")
    func weightsSum() {
        let sum =
            SRTConnectionQuality.rttWeight
            + SRTConnectionQuality.lossWeight
            + SRTConnectionQuality.bufferWeight
            + SRTConnectionQuality.bitrateWeight
            + SRTConnectionQuality.stabilityWeight
        #expect(abs(sum - 1.0) < 0.001)
    }
}
