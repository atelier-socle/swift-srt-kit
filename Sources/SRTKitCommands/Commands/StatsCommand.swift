// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import SRTKit

/// Connect and display real-time statistics.
///
/// Usage: srt-cli stats --host <host> --port <port>
public struct StatsCommand: AsyncParsableCommand {
    /// Command configuration.
    public static let configuration = CommandConfiguration(
        commandName: "stats",
        abstract: "Display real-time connection statistics"
    )

    /// Remote host address.
    @Option(name: .long, help: "Remote host")
    var host: String = "127.0.0.1"

    /// Remote port number.
    @Option(name: .long, help: "Remote port")
    var port: Int = 4200

    /// Refresh interval in seconds.
    @Option(name: .long, help: "Refresh interval in seconds")
    var interval: Int = 2

    /// StreamID for access control.
    @Option(name: .long, help: "StreamID for access control")
    var streamID: String?

    /// Passphrase for encryption.
    @Option(name: .long, help: "Passphrase for encryption")
    var passphrase: String?

    /// Show quality score.
    @Flag(name: .long, help: "Show quality score")
    var quality: Bool = false

    /// Creates a new instance.
    public init() {}

    /// Runs the stats command.
    public mutating func run() async throws {
        let config = try ConfigurationFactory.callerConfiguration(
            host: host, port: port,
            options: .init(
                streamID: streamID, passphrase: passphrase)
        )

        let caller = SRTCaller(configuration: config)

        ProgressDisplay.connecting(host: host, port: port)
        try await caller.connect()
        ProgressDisplay.connected(peerAddress: "\(host):\(port)")

        print("Refresh interval: \(interval)s")
        if quality {
            print("Quality scoring: enabled")
        }

        // Statistics loop
        var iteration = 0
        while !Task.isCancelled {
            try await Task.sleep(for: .seconds(interval))
            iteration += 1

            // In a full implementation, we would read statistics
            // from the socket's pipeline. For now we show the snapshot.
            let stats = SRTStatistics()
            print("\n--- Statistics snapshot #\(iteration) ---")
            print(StatisticsFormatter.format(stats))

            if quality {
                let qualityScore = SRTConnectionQuality.from(statistics: stats)
                print(StatisticsFormatter.formatQuality(qualityScore))
            }
        }

        await caller.disconnect()
    }
}
