// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser

/// Display version and feature information.
///
/// Usage: srt-cli info
public struct InfoCommand: AsyncParsableCommand {
    /// Command configuration.
    public static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: "Display version and feature information"
    )

    /// Show detailed feature list.
    @Flag(name: .long, help: "Show detailed feature list")
    var verbose: Bool = false

    /// Creates a new instance.
    public init() {}

    /// Runs the info command.
    public mutating func run() async throws {
        print("srt-cli v0.2.0")
        print("Secure Reliable Transport — Pure Swift Implementation")
        print("")
        print("Features:")
        print("  Encryption:  AES-CTR + AES-GCM (128/192/256-bit)")
        print("  FEC:         XOR-based row/column recovery")
        print("  Congestion:  LiveCC, FileCC, Adaptive plugin")
        print("  Bonding:     Broadcast, Main/Backup, Balancing")
        print("  Probing:     Bandwidth probing + adaptive bitrate")
        print("  Recording:   Stream recording with rotation")
        print("  Statistics:  Real-time metrics, Prometheus, StatsD")

        if verbose {
            print("")
            print("Presets:")
            print("  lowLatency     — Minimal latency for real-time")
            print("  balanced       — Balance latency and reliability")
            print("  reliable       — Maximum reliability")
            print("  highBandwidth  — High throughput streaming")
            print("  broadcast      — Broadcast-grade delivery")
            print("  fileTransfer   — Reliable file transfer")
            print("")
            print("Server Presets:")
            print("  awsMediaConnect, nimbleStreamer, haivisionHub,")
            print("  vmix, obsStudio, srsServer, wowzaStreaming")
        }
    }
}
