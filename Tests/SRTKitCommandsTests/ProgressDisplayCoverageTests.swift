// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKitCommands

@Suite("ProgressDisplay Coverage Tests")
struct ProgressDisplayCoverageTests {

    @Test("connecting prints to stderr without crash")
    func connectingPrints() {
        ProgressDisplay.connecting(host: "127.0.0.1", port: 4200)
        // No crash = success (output goes to stderr)
    }

    @Test("listening prints to stderr without crash")
    func listeningPrints() {
        ProgressDisplay.listening(host: "0.0.0.0", port: 4200)
    }

    @Test("connected prints to stderr without crash")
    func connectedPrints() {
        ProgressDisplay.connected(peerAddress: "10.0.0.1:4200")
    }

    @Test("transferProgress prints to stderr without crash")
    func transferProgressPrints() {
        ProgressDisplay.transferProgress(
            bytes: 1_048_576, packets: 100, elapsed: 5.0)
    }

    @Test("transferProgress with zero elapsed handles gracefully")
    func transferProgressZeroElapsed() {
        ProgressDisplay.transferProgress(
            bytes: 0, packets: 0, elapsed: 0)
    }

    @Test("summary prints to stderr without crash")
    func summaryPrints() {
        ProgressDisplay.summary(
            totalBytes: 10_485_760, totalPackets: 1000, duration: 10.0)
    }

    @Test("summary with zero duration handles gracefully")
    func summaryZeroDuration() {
        ProgressDisplay.summary(
            totalBytes: 0, totalPackets: 0, duration: 0)
    }

    @Test("error prints to stderr without crash")
    func errorPrints() {
        ProgressDisplay.error("connection timed out")
    }
}
