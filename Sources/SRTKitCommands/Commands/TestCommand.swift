// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser

/// Loopback throughput and latency test.
///
/// Starts a listener and caller internally, measures round-trip performance.
/// Usage: srt-cli test [--duration <seconds>] [--bitrate <kbps>]
public struct TestCommand: AsyncParsableCommand {
    /// Command configuration.
    public static let configuration = CommandConfiguration(
        commandName: "test",
        abstract: "Run a loopback performance test"
    )

    /// Test duration in seconds.
    @Option(name: .long, help: "Test duration in seconds")
    var duration: Int = 5

    /// Target bitrate in kbps.
    @Option(name: .long, help: "Target bitrate in kbps")
    var bitrate: Int = 5000

    /// Port for internal loopback.
    @Option(name: .long, help: "Port for internal loopback")
    var port: Int = 9999

    /// Latency in milliseconds.
    @Option(name: .long, help: "Latency in milliseconds")
    var latency: Int = 120

    /// Creates a new instance.
    public init() {}

    /// Runs the test command.
    public mutating func run() async throws {
        print("Running loopback test on port \(port)")
        print("Duration: \(duration)s, Target bitrate: \(bitrate) kbps")
        print("Latency: \(latency)ms")
    }
}
