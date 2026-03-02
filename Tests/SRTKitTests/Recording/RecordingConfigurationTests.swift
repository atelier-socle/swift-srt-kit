// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("RecordingConfiguration Tests")
struct RecordingConfigurationTests {
    @Test("Default configuration values")
    func defaultConfig() {
        let config = RecordingConfiguration.default
        #expect(config.format == .mpegts)
        #expect(config.maxFileSizeBytes == nil)
        #expect(config.maxDurationMicroseconds == nil)
        #expect(config.flushIntervalMicroseconds == 1_000_000)
    }

    @Test("Custom init sets all fields")
    func customInit() {
        let config = RecordingConfiguration(
            format: .raw,
            maxFileSizeBytes: 1_000_000,
            maxDurationMicroseconds: 60_000_000,
            flushIntervalMicroseconds: 500_000
        )
        #expect(config.format == .raw)
        #expect(config.maxFileSizeBytes == 1_000_000)
        #expect(config.maxDurationMicroseconds == 60_000_000)
        #expect(config.flushIntervalMicroseconds == 500_000)
    }

    @Test("Equatable: same values are equal")
    func equatableSame() {
        let a = RecordingConfiguration.default
        let b = RecordingConfiguration.default
        #expect(a == b)
    }

    @Test("Equatable: different values are not equal")
    func equatableDifferent() {
        let a = RecordingConfiguration.default
        let b = RecordingConfiguration(format: .raw)
        #expect(a != b)
    }

    @Test("RecordingFormat cases")
    func recordingFormatCases() {
        #expect(RecordingFormat.allCases.count == 2)
        #expect(RecordingFormat.raw.rawValue == "raw")
        #expect(RecordingFormat.mpegts.rawValue == "mpegts")
    }

    @Test("RecordingStatistics default values")
    func recordingStatisticsDefault() {
        let stats = RecordingStatistics()
        #expect(stats.totalBytesWritten == 0)
        #expect(stats.durationMicroseconds == 0)
        #expect(stats.fileRotations == 0)
        #expect(stats.currentFileBytesWritten == 0)
        #expect(stats.flushCount == 0)
    }
}
