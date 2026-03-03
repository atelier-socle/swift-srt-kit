// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit
@testable import SRTKitCommands

@Suite("StatisticsFormatter Tests")
struct StatisticsFormatterTests {
    // MARK: - formatBytes

    @Test("0 bytes")
    func zeroBytes() {
        #expect(StatisticsFormatter.formatBytes(0) == "0 B")
    }

    @Test("1023 bytes")
    func bytesUnderKB() {
        #expect(StatisticsFormatter.formatBytes(1023) == "1023 B")
    }

    @Test("1024 bytes = 1.0 KB")
    func oneKB() {
        #expect(StatisticsFormatter.formatBytes(1024) == "1.0 KB")
    }

    @Test("1 MB")
    func oneMB() {
        #expect(StatisticsFormatter.formatBytes(1_048_576) == "1.0 MB")
    }

    @Test("1 GB")
    func oneGB() {
        #expect(StatisticsFormatter.formatBytes(1_073_741_824) == "1.0 GB")
    }

    // MARK: - formatDuration

    @Test("0 microseconds")
    func zeroDuration() {
        #expect(StatisticsFormatter.formatDuration(0) == "0us")
    }

    @Test("999 microseconds")
    func subMillisecond() {
        #expect(StatisticsFormatter.formatDuration(999) == "999us")
    }

    @Test("1000 microseconds = 1.0ms")
    func oneMillisecond() {
        #expect(StatisticsFormatter.formatDuration(1_000) == "1.0ms")
    }

    @Test("1 second")
    func oneSecond() {
        #expect(StatisticsFormatter.formatDuration(1_000_000) == "1.0s")
    }

    @Test("60 seconds = 1m 0s")
    func oneMinute() {
        #expect(StatisticsFormatter.formatDuration(60_000_000) == "1m 0s")
    }

    // MARK: - formatBitrate

    @Test("0 bps")
    func zeroBitrate() {
        #expect(StatisticsFormatter.formatBitrate(0) == "0 bps")
    }

    @Test("999 bps")
    func subKbps() {
        #expect(StatisticsFormatter.formatBitrate(999) == "999 bps")
    }

    @Test("1000 bps = 1.0 Kbps")
    func oneKbps() {
        #expect(StatisticsFormatter.formatBitrate(1_000) == "1.0 Kbps")
    }

    @Test("1 Mbps")
    func oneMbps() {
        #expect(StatisticsFormatter.formatBitrate(1_000_000) == "1.0 Mbps")
    }

    @Test("1 Gbps")
    func oneGbps() {
        #expect(StatisticsFormatter.formatBitrate(1_000_000_000) == "1.0 Gbps")
    }

    // MARK: - format (full stats)

    @Test("Default statistics produce non-empty output")
    func formatDefaultStats() {
        let stats = SRTStatistics()
        let output = StatisticsFormatter.format(stats)
        #expect(!output.isEmpty)
    }

    @Test("Output contains key headers")
    func outputContainsHeaders() {
        let stats = SRTStatistics()
        let output = StatisticsFormatter.format(stats)
        #expect(output.contains("Packets"))
        #expect(output.contains("Bytes"))
        #expect(output.contains("RTT"))
    }

    // MARK: - formatCompact

    @Test("Compact is single line")
    func compactSingleLine() {
        let stats = SRTStatistics()
        let output = StatisticsFormatter.formatCompact(stats)
        let newlineCount = output.filter { $0 == "\n" }.count
        #expect(newlineCount == 0)
    }

    // MARK: - formatQuality

    @Test("Excellent grade contains Excellent")
    func excellentGrade() {
        let quality = SRTConnectionQuality(
            score: 0.95,
            grade: .excellent,
            rttScore: 0.95,
            lossScore: 0.95,
            bufferScore: 0.95,
            bitrateEfficiencyScore: 0.95,
            stabilityScore: 0.95,
            recommendation: nil)
        let output = StatisticsFormatter.formatQuality(quality)
        #expect(output.contains("excellent"))
    }

    @Test("Critical grade contains critical")
    func criticalGrade() {
        let quality = SRTConnectionQuality(
            score: 0.1,
            grade: .critical,
            rttScore: 0.1,
            lossScore: 0.1,
            bufferScore: 0.1,
            bitrateEfficiencyScore: 0.1,
            stabilityScore: 0.1,
            recommendation: nil)
        let output = StatisticsFormatter.formatQuality(quality)
        #expect(output.contains("critical"))
    }
}
