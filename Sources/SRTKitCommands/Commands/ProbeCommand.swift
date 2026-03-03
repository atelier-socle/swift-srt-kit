// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser

/// Bandwidth probe with recommendations.
///
/// Usage: srt-cli probe --host <host> --port <port>
public struct ProbeCommand: AsyncParsableCommand {
    /// Command configuration.
    public static let configuration = CommandConfiguration(
        commandName: "probe",
        abstract: "Probe available bandwidth and get recommendations"
    )

    /// Remote host address.
    @Option(name: .long, help: "Remote host")
    var host: String = "127.0.0.1"

    /// Remote port number.
    @Option(name: .long, help: "Remote port")
    var port: Int = 4200

    /// Probe mode.
    @Option(name: .long, help: "Probe mode: quick, standard, thorough")
    var mode: String = "standard"

    /// Target quality.
    @Option(name: .long, help: "Target quality: quality, balanced, lowLatency")
    var target: String = "balanced"

    /// Creates a new instance.
    public init() {}

    /// Runs the probe command.
    public mutating func run() async throws {
        print("Probing \(host):\(port)")
        print("Mode: \(mode), Target: \(target)")
    }
}
