// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import SRTKit

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
        let config = ConfigurationFactory.listenerConfiguration(
            bind: bind, port: port,
            passphrase: passphrase, latency: latency
        )

        let listener = SRTListener(configuration: config)

        ProgressDisplay.listening(host: bind, port: port)
        try await listener.start()

        let actualPort = await listener.boundPort ?? port
        if actualPort != port {
            ProgressDisplay.listening(host: bind, port: actualPort)
        }

        let outputHandle = try openOutputHandle()
        let durationSeconds = duration
        let startTime = ContinuousClock.now

        let (totalBytes, totalPackets) = await receiveData(
            listener: listener,
            outputHandle: outputHandle,
            durationSeconds: durationSeconds,
            startTime: startTime
        )

        if output != nil {
            outputHandle.closeFile()
        }

        ProgressDisplay.summary(
            totalBytes: totalBytes,
            totalPackets: totalPackets,
            duration: elapsedSeconds(since: startTime)
        )

        await listener.stop()
    }

    /// Open the output file handle (or stdout).
    private func openOutputHandle() throws -> FileHandle {
        if let outputPath = output {
            FileManager.default.createFile(
                atPath: outputPath, contents: nil)
            guard let handle = FileHandle(forWritingAtPath: outputPath)
            else {
                throw CLIError.fileNotFound(path: outputPath)
            }
            return handle
        }
        return FileHandle.standardOutput
    }

    /// Receive data from the first connection.
    private func receiveData(
        listener: SRTListener,
        outputHandle: FileHandle,
        durationSeconds: Int,
        startTime: ContinuousClock.Instant
    ) async -> (UInt64, UInt64) {
        var totalBytes: UInt64 = 0
        var totalPackets: UInt64 = 0
        let connections = await listener.incomingConnections

        for await socket in connections {
            ProgressDisplay.connected(peerAddress: "peer")

            while true {
                if durationSeconds > 0 {
                    let elapsed = elapsedSeconds(since: startTime)
                    if elapsed >= Double(durationSeconds) { break }
                }

                guard let data = await socket.receive() else { break }
                outputHandle.write(Data(data))
                totalBytes += UInt64(data.count)
                totalPackets += 1
                ProgressDisplay.transferProgress(
                    bytes: totalBytes,
                    packets: totalPackets,
                    elapsed: elapsedSeconds(since: startTime)
                )
            }
            break
        }

        return (totalBytes, totalPackets)
    }

    /// Calculate elapsed seconds from a start time.
    private func elapsedSeconds(
        since start: ContinuousClock.Instant
    ) -> Double {
        let elapsed = start.duration(to: ContinuousClock.now)
        let (seconds, attoseconds) = elapsed.components
        return Double(seconds) + Double(attoseconds) / 1e18
    }
}
