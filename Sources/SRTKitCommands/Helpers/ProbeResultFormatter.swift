// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import SRTKit

/// Formats ProbeResult for terminal display.
public struct ProbeResultFormatter: Sendable {
    /// Format a full probe result as a multi-line table.
    ///
    /// - Parameter result: The probe result to format.
    /// - Returns: Multi-line formatted string.
    public static func format(_ result: ProbeResult) -> String {
        var lines: [String] = []
        lines.append("=== Probe Results ===")
        lines.append("")
        lines.append(
            "Achieved bandwidth: \(StatisticsFormatter.formatBitrate(result.achievedBandwidth))"
        )
        lines.append(
            "Average RTT:        \(StatisticsFormatter.formatDuration(result.averageRTTMicroseconds))"
        )
        lines.append(
            "Packet loss:        \(String(format: "%.2f%%", result.packetLossRate * 100))"
        )
        lines.append("Stability score:    \(result.stabilityScore)/100")
        lines.append("Steps completed:    \(result.stepsCompleted)")
        lines.append(
            "Total duration:     \(StatisticsFormatter.formatDuration(result.totalDurationMicroseconds))"
        )
        if let satIdx = result.saturationStepIndex {
            lines.append("Saturation at step: \(satIdx)")
        }
        lines.append("")
        lines.append(
            "Recommended bitrate: \(StatisticsFormatter.formatBitrate(result.recommendedBitrate))"
        )
        lines.append(
            "Recommended latency: \(StatisticsFormatter.formatDuration(result.recommendedLatency))"
        )
        return lines.joined(separator: "\n")
    }

    /// Format per-step measurements.
    ///
    /// - Parameter measurements: Array of step measurements.
    /// - Returns: Multi-line formatted string with one row per step.
    public static func formatSteps(
        _ measurements: [StepMeasurement]
    ) -> String {
        guard !measurements.isEmpty else { return "" }
        var lines: [String] = []
        lines.append("Step | Target      | Achieved    | RTT       | Loss   | Sat")
        lines.append("-----+-------------+-------------+-----------+--------+----")
        for m in measurements {
            let target = StatisticsFormatter.formatBitrate(m.targetBitrate)
            let achieved = StatisticsFormatter.formatBitrate(m.achievedSendRate)
            let rtt = StatisticsFormatter.formatDuration(m.rttMicroseconds)
            let loss = String(format: "%.2f%%", m.lossRate * 100)
            let sat = m.saturated ? "Y" : "N"
            let idx = String(format: "%4d", m.stepIndex)
            lines.append(
                "\(idx) | \(target) | \(achieved) | \(rtt) | \(loss) | \(sat)")
        }
        return lines.joined(separator: "\n")
    }

    /// Format recommendations based on probe result and target quality.
    ///
    /// - Parameters:
    ///   - result: The probe result.
    ///   - targetQuality: The target quality level.
    /// - Returns: Multi-line formatted recommendation string.
    public static func formatRecommendations(
        _ result: ProbeResult,
        targetQuality: TargetQuality
    ) -> String {
        var lines: [String] = []
        lines.append("=== Recommendations ===")
        lines.append("")
        lines.append("Target quality:      \(targetQuality)")
        lines.append("Bandwidth factor:    \(targetQuality.bandwidthFactor)")
        lines.append(
            "Recommended bitrate: \(StatisticsFormatter.formatBitrate(result.recommendedBitrate))"
        )
        lines.append(
            "Recommended latency: \(StatisticsFormatter.formatDuration(result.recommendedLatency))"
        )
        return lines.joined(separator: "\n")
    }
}
