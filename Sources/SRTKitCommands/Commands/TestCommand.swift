// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import SRTKit

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

    /// Loopback infrastructure.
    private struct LoopbackSetup {
        let listener: SRTListener
        let caller: SRTCaller
        let receiveTask: Task<(UInt64, UInt64), Never>
    }

    /// Runs the test command.
    public mutating func run() async throws {
        print("Running loopback test on port \(port)")
        print("Duration: \(duration)s, Target bitrate: \(bitrate) kbps")
        print("Latency: \(latency)ms")
        print("")

        let setup = try await startLoopback()
        let startTime = ContinuousClock.now

        let (sentBytes, sentPackets) =
            try await sendTestData(caller: setup.caller)

        let totalDuration = elapsedSeconds(since: startTime)
        let stats = await setup.caller.statistics()

        await setup.caller.disconnect()
        setup.receiveTask.cancel()
        await setup.listener.stop()

        printResults(
            sentBytes: sentBytes,
            sentPackets: sentPackets,
            totalDuration: totalDuration,
            statistics: stats
        )
    }

    /// Start the loopback listener and caller pair.
    private func startLoopback() async throws -> LoopbackSetup {
        let latencyUs = UInt64(latency) * 1000

        let listenerConfig = SRTListener.Configuration(
            host: "127.0.0.1",
            port: port,
            latency: latencyUs
        )
        let listener = SRTListener(configuration: listenerConfig)
        try await listener.start()

        let actualPort = await listener.boundPort ?? port
        print("Listener started on port \(actualPort)")

        let callerConfig = SRTCaller.Configuration(
            host: "127.0.0.1",
            port: actualPort,
            latency: latencyUs
        )
        let caller = SRTCaller(configuration: callerConfig)

        let receiveTask = Task {
            var receivedBytes: UInt64 = 0
            var receivedPackets: UInt64 = 0
            let connections = await listener.incomingConnections
            for await socket in connections {
                while let data = await socket.receive() {
                    receivedBytes += UInt64(data.count)
                    receivedPackets += 1
                }
                break
            }
            return (receivedBytes, receivedPackets)
        }

        print("Connecting...")
        try await caller.connect()
        print("Connected, starting data transfer...")

        return LoopbackSetup(
            listener: listener, caller: caller,
            receiveTask: receiveTask)
    }

    /// Send test data at the configured bitrate for the configured duration.
    private func sendTestData(
        caller: SRTCaller
    ) async throws -> (UInt64, UInt64) {
        let chunkSize = 1316
        let bytesPerSecond = UInt64(bitrate) * 1000 / 8
        let packetIntervalNs = UInt64(
            Double(chunkSize) / Double(bytesPerSecond) * 1_000_000_000)
        let testData = [UInt8](repeating: 0xAB, count: chunkSize)

        var sentBytes: UInt64 = 0
        var sentPackets: UInt64 = 0
        let startTime = ContinuousClock.now

        while true {
            let elapsed = startTime.duration(to: ContinuousClock.now)
            let (seconds, _) = elapsed.components
            if seconds >= Int64(duration) { break }

            _ = try await caller.send(testData)
            sentBytes += UInt64(chunkSize)
            sentPackets += 1

            if packetIntervalNs > 0 {
                try await Task.sleep(nanoseconds: packetIntervalNs)
            }
        }

        return (sentBytes, sentPackets)
    }

    /// Calculate elapsed seconds from a start time.
    private func elapsedSeconds(
        since start: ContinuousClock.Instant
    ) -> Double {
        let elapsed = start.duration(to: ContinuousClock.now)
        let (seconds, attoseconds) = elapsed.components
        return Double(seconds) + Double(attoseconds) / 1e18
    }

    /// Print test results summary.
    private func printResults(
        sentBytes: UInt64,
        sentPackets: UInt64,
        totalDuration: Double,
        statistics: SRTStatistics
    ) {
        let actualBitrate =
            totalDuration > 0
            ? Double(sentBytes) * 8.0 / totalDuration
            : 0

        print("")
        print("=== Test Results ===")
        print(
            "Duration:        \(String(format: "%.1f", totalDuration))s")
        print(
            "Sent:            \(sentBytes) bytes (\(sentPackets) packets)"
        )
        print("Target bitrate:  \(bitrate) kbps")
        print(
            "Actual bitrate:  \(String(format: "%.0f", actualBitrate / 1000)) kbps"
        )
        print("Latency:         \(latency)ms")
        print("")
        print("=== Connection Statistics ===")
        print("Packets sent:    \(statistics.packetsSent)")
        print("Packets recv:    \(statistics.packetsReceived)")
        print("Bytes sent:      \(StatisticsFormatter.formatBytes(statistics.bytesSent))")
        print(
            "RTT:             \(StatisticsFormatter.formatDuration(statistics.rttMicroseconds))"
        )
        print(
            "Loss rate:       \(String(format: "%.2f%%", statistics.lossRate * 100))"
        )
    }
}
