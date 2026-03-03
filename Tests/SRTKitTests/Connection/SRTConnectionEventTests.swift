// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTConnectionEvent Tests")
struct SRTConnectionEventTests {
    @Test("bitrateRecommendation event carries recommendation")
    func bitrateRecommendationEvent() {
        let recommendation = BitrateRecommendation(
            recommendedBitrate: 4_000_000,
            currentBitrate: 5_000_000,
            direction: .decrease,
            reason: .packetLoss,
            confidence: 0.85
        )
        let event = SRTConnectionEvent.bitrateRecommendation(recommendation)
        if case .bitrateRecommendation(let r) = event {
            #expect(r.recommendedBitrate == 4_000_000)
            #expect(r.direction == .decrease)
            #expect(r.reason == .packetLoss)
            #expect(r.confidence == 0.85)
        } else {
            #expect(Bool(false), "Expected bitrateRecommendation event")
        }
    }

    @Test("recordingUpdate event carries statistics")
    func recordingUpdateEvent() {
        var stats = RecordingStatistics()
        stats.totalBytesWritten = 1_048_576
        stats.fileRotations = 3
        stats.flushCount = 42
        let event = SRTConnectionEvent.recordingUpdate(stats)
        if case .recordingUpdate(let s) = event {
            #expect(s.totalBytesWritten == 1_048_576)
            #expect(s.fileRotations == 3)
            #expect(s.flushCount == 42)
        } else {
            #expect(Bool(false), "Expected recordingUpdate event")
        }
    }

    @Test("bitrateRecommendation maintain direction")
    func bitrateRecommendationMaintain() {
        let recommendation = BitrateRecommendation(
            recommendedBitrate: 2_000_000,
            currentBitrate: 2_000_000,
            direction: .maintain,
            reason: .stable,
            confidence: 0.95
        )
        let event = SRTConnectionEvent.bitrateRecommendation(recommendation)
        if case .bitrateRecommendation(let r) = event {
            #expect(r.direction == .maintain)
            #expect(r.reason == .stable)
        } else {
            #expect(Bool(false), "Expected bitrateRecommendation event")
        }
    }

    @Test("recordingUpdate default statistics")
    func recordingUpdateDefault() {
        let stats = RecordingStatistics()
        let event = SRTConnectionEvent.recordingUpdate(stats)
        if case .recordingUpdate(let s) = event {
            #expect(s.totalBytesWritten == 0)
            #expect(s.fileRotations == 0)
            #expect(s.flushCount == 0)
        } else {
            #expect(Bool(false), "Expected recordingUpdate event")
        }
    }
}
