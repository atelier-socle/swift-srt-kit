// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import SRTKit

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
        let config = try ConfigurationFactory.callerConfiguration(
            host: host, port: port,
            options: .init(
                streamID: streamID, passphrase: passphrase,
                preset: preset, latency: latency)
        )

        let caller = SRTCaller(configuration: config)

        ProgressDisplay.connecting(host: host, port: port)
        try await caller.connect()
        ProgressDisplay.connected(peerAddress: "\(host):\(port)")

        let chunkSize = 1316
        var totalBytes: UInt64 = 0
        var totalPackets: UInt64 = 0
        let startTime = ContinuousClock.now

        do {
            if let filePath = file {
                guard FileManager.default.fileExists(atPath: filePath) else {
                    throw CLIError.fileNotFound(path: filePath)
                }
                guard let handle = FileHandle(forReadingAtPath: filePath) else {
                    throw CLIError.fileNotFound(path: filePath)
                }
                defer { handle.closeFile() }

                while true {
                    let data = handle.readData(ofLength: chunkSize)
                    if data.isEmpty { break }
                    let bytes = Array(data)
                    _ = try await caller.send(bytes)
                    totalBytes += UInt64(bytes.count)
                    totalPackets += 1
                    let elapsed = elapsedSeconds(since: startTime)
                    ProgressDisplay.transferProgress(
                        bytes: totalBytes,
                        packets: totalPackets,
                        elapsed: elapsed
                    )
                }
            } else {
                // Read from stdin
                while let data = readLine(strippingNewline: false) {
                    let bytes = Array(data.utf8)
                    guard !bytes.isEmpty else { continue }
                    for start in stride(from: 0, to: bytes.count, by: chunkSize) {
                        let end = min(start + chunkSize, bytes.count)
                        let chunk = Array(bytes[start..<end])
                        _ = try await caller.send(chunk)
                        totalBytes += UInt64(chunk.count)
                        totalPackets += 1
                    }
                }
            }
        } catch {
            ProgressDisplay.error(String(describing: error))
        }

        let duration = elapsedSeconds(since: startTime)
        ProgressDisplay.summary(
            totalBytes: totalBytes,
            totalPackets: totalPackets,
            duration: duration
        )

        await caller.disconnect()
    }

    /// Calculate elapsed seconds from a start time.
    private func elapsedSeconds(since start: ContinuousClock.Instant) -> Double {
        let elapsed = start.duration(to: ContinuousClock.now)
        let (seconds, attoseconds) = elapsed.components
        return Double(seconds) + Double(attoseconds) / 1e18
    }
}
