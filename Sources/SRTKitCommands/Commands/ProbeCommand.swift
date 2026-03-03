// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import SRTKit

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
        let probeConfig = try PresetParser.parseProbeConfiguration(mode)
        let targetQuality = try PresetParser.parseTargetQuality(target)

        ProgressDisplay.connecting(host: host, port: port)

        let callerConfig = try ConfigurationFactory.callerConfiguration(
            host: host, port: port
        )
        let caller = SRTCaller(configuration: callerConfig)

        try await caller.connect()
        ProgressDisplay.connected(peerAddress: "\(host):\(port)")

        print("Probing with mode: \(mode), target: \(target)")
        print("Steps: \(probeConfig.steps.count)")
        print("")

        // Run probe engine
        var engine = ProbeEngine(configuration: probeConfig)
        var action = engine.start()
        let chunkSize = 1316

        probeLoop: while true {
            switch action {
            case .sendAtBitrate(let bps, let stepIndex):
                print("Step \(stepIndex + 1): sending at \(bps / 1000) kbps...")
                let stepStart = SystemSRTClock().now()
                let bytesPerSecond = bps / 8
                let packetInterval =
                    bytesPerSecond > 0
                    ? Double(chunkSize) / Double(bytesPerSecond)
                    : 0.1
                let stepDuration = probeConfig.stepDurationMicroseconds

                let testData = [UInt8](repeating: 0xBB, count: chunkSize)
                let deadline = stepStart + stepDuration

                while SystemSRTClock().now() < deadline {
                    _ = try? await caller.send(testData)
                    if packetInterval > 0 {
                        try await Task.sleep(
                            nanoseconds: UInt64(packetInterval * 1_000_000_000))
                    }
                }

                let currentTime = SystemSRTClock().now()
                let stats = await caller.statistics()
                action = engine.feedStepResult(
                    statistics: stats,
                    stepStartTime: stepStart,
                    currentTime: currentTime
                )

            case .complete(let result):
                print("")
                print(ProbeResultFormatter.format(result))
                print("")
                print(
                    ProbeResultFormatter.formatRecommendations(
                        result, targetQuality: targetQuality))
                break probeLoop

            case .failed(let reason):
                ProgressDisplay.error("Probe failed: \(reason)")
                break probeLoop
            }
        }

        await caller.disconnect()
    }
}
