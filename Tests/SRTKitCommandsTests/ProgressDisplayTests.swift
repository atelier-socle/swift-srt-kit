// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKitCommands

@Suite("ProgressDisplay Tests")
struct ProgressDisplayTests {

    @Test("formatBytes handles zero")
    func formatBytesZero() {
        #expect(ProgressDisplay.formatBytes(0) == "0 B")
    }

    @Test("formatBytes handles bytes")
    func formatBytesSmall() {
        #expect(ProgressDisplay.formatBytes(512) == "512 B")
    }

    @Test("formatBytes handles kilobytes")
    func formatBytesKB() {
        let result = ProgressDisplay.formatBytes(2048)
        #expect(result == "2.0 KB")
    }

    @Test("formatBytes handles megabytes")
    func formatBytesMB() {
        let result = ProgressDisplay.formatBytes(5_242_880)
        #expect(result == "5.0 MB")
    }

    @Test("formatBytes handles gigabytes")
    func formatBytesGB() {
        let result = ProgressDisplay.formatBytes(2_147_483_648)
        #expect(result == "2.00 GB")
    }

    @Test("formatBitrate handles small values")
    func formatBitrateSmall() {
        #expect(ProgressDisplay.formatBitrate(500) == "500 bps")
    }

    @Test("formatBitrate handles kbps")
    func formatBitrateKbps() {
        let result = ProgressDisplay.formatBitrate(5000)
        #expect(result == "5.0 Kbps")
    }

    @Test("formatBitrate handles Mbps")
    func formatBitrateMbps() {
        let result = ProgressDisplay.formatBitrate(10_000_000)
        #expect(result == "10.0 Mbps")
    }
}
