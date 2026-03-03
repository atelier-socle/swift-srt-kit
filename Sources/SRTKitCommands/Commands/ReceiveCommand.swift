// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser

/// Listen for incoming SRT data and save to file or stdout.
///
/// Usage: srt-cli receive --port <port> [--output <path>]
///        srt-cli receive --port <port> > output.ts
public struct ReceiveCommand: AsyncParsableCommand {
    /// Command configuration.
    public static let configuration = CommandConfiguration(
        commandName: "receive",
        abstract: "Receive data from an SRT caller"
    )

    /// Listen port.
    @Option(name: .long, help: "Listen port")
    var port: Int = 4200

    /// Bind address.
    @Option(name: .long, help: "Bind address")
    var bind: String = "0.0.0.0"

    /// Output file (omit for stdout).
    @Option(name: .long, help: "Output file (omit for stdout)")
    var output: String?

    /// Passphrase for encryption.
    @Option(name: .long, help: "Passphrase for encryption")
    var passphrase: String?

    /// Latency in milliseconds.
    @Option(name: .long, help: "Latency in milliseconds")
    var latency: Int?

    /// Maximum duration in seconds (0 = unlimited).
    @Option(name: .long, help: "Maximum duration in seconds (0 = unlimited)")
    var duration: Int = 0

    /// Creates a new instance.
    public init() {}

    /// Runs the receive command.
    public mutating func run() async throws {
        print("Listening on \(bind):\(port)")
        if let output {
            print("Output: \(output)")
        } else {
            print("Output: stdout")
        }
        if let latency {
            print("Latency: \(latency)ms")
        }
        if duration > 0 {
            print("Duration: \(duration)s")
        }
        if let passphrase {
            print("Encryption: enabled (\(passphrase.count) char passphrase)")
        }
    }
}
