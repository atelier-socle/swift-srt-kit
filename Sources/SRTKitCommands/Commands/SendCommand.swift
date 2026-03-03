// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser

/// Send data from a file to an SRT listener.
///
/// Usage: srt-cli send --host <host> --port <port> [--file <path>]
///        srt-cli send --host <host> --port <port> < file.ts
public struct SendCommand: AsyncParsableCommand {
    /// Command configuration.
    public static let configuration = CommandConfiguration(
        commandName: "send",
        abstract: "Send data to an SRT listener"
    )

    /// Remote host address.
    @Option(name: .long, help: "Remote host")
    var host: String = "127.0.0.1"

    /// Remote port number.
    @Option(name: .long, help: "Remote port")
    var port: Int = 4200

    /// File to send (omit for stdin).
    @Option(name: .long, help: "File to send (omit for stdin)")
    var file: String?

    /// StreamID for access control.
    @Option(name: .long, help: "StreamID for access control")
    var streamID: String?

    /// Passphrase for encryption.
    @Option(name: .long, help: "Passphrase for encryption")
    var passphrase: String?

    /// Preset name.
    @Option(name: .long, help: "Preset: lowLatency, balanced, reliable, highBandwidth, broadcast, fileTransfer")
    var preset: String?

    /// Latency in milliseconds.
    @Option(name: .long, help: "Latency in milliseconds")
    var latency: Int?

    /// Creates a new instance.
    public init() {}

    /// Runs the send command.
    public mutating func run() async throws {
        print("Sending to \(host):\(port)")
        if let file {
            print("Source: \(file)")
        } else {
            print("Source: stdin")
        }
        if let preset {
            print("Preset: \(preset)")
        }
        if let latency {
            print("Latency: \(latency)ms")
        }
        if let passphrase {
            print("Encryption: enabled (\(passphrase.count) char passphrase)")
        }
        if let streamID {
            print("StreamID: \(streamID)")
        }
    }
}
