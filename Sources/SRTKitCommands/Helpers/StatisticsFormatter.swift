// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import SRTKit

/// Formats SRTStatistics for terminal display.
///
/// Produces pretty-printed tables suitable for terminal output.
public struct StatisticsFormatter: Sendable {
    /// Format a statistics snapshot as a multi-line table string.
    ///
    /// - Parameter statistics: The statistics to format.
    /// - Returns: Multi-line formatted string.
    public static func format(_ statistics: SRTStatistics) -> String {
        var lines: [String] = []
        lines.append("=== SRT Statistics ===")
        lines.append("")
        lines.append("Packets:")
        lines.append("  Sent:          \(statistics.packetsSent)")
        lines.append("  Received:      \(statistics.packetsReceived)")
        lines.append("  Lost (sent):   \(statistics.packetsSentLost)")
        lines.append("  Lost (recv):   \(statistics.packetsReceivedLost)")
        lines.append("  Retransmitted: \(statistics.packetsRetransmitted)")
        lines.append("  Dropped:       \(statistics.packetsDropped)")
        lines.append("  FEC recovered: \(statistics.packetsFECRecovered)")
        lines.append("")
        lines.append("Bytes:")
        lines.append("  Sent:          \(formatBytes(statistics.bytesSent))")
        lines.append("  Received:      \(formatBytes(statistics.bytesReceived))")
        lines.append("  Retransmitted: \(formatBytes(statistics.bytesRetransmitted))")
        lines.append("  Dropped:       \(formatBytes(statistics.bytesDropped))")
        lines.append("")
        lines.append("RTT:")
        lines.append(
            "  Current:       \(formatDuration(statistics.rttMicroseconds))")
        lines.append(
            "  Variance:      \(formatDuration(statistics.rttVarianceMicroseconds))"
        )
        lines.append("")
        lines.append("Bandwidth:")
        lines.append(
            "  Estimated:     \(formatBitrate(statistics.bandwidthBitsPerSecond))"
        )
        lines.append(
            "  Send rate:     \(formatBitrate(statistics.sendRateBitsPerSecond))"
        )
        lines.append(
            "  Receive rate:  \(formatBitrate(statistics.receiveRateBitsPerSecond))"
        )
        lines.append("")
        lines.append("Buffers:")
        lines.append(
            "  Send:          \(statistics.sendBufferPackets)/\(statistics.sendBufferCapacity)"
        )
        lines.append(
            "  Receive:       \(statistics.receiveBufferPackets)/\(statistics.receiveBufferCapacity)"
        )
        lines.append("  In flight:     \(statistics.packetsInFlight)")
        return lines.joined(separator: "\n")
    }

    /// Format a compact one-line summary.
    ///
    /// - Parameter statistics: The statistics to format.
    /// - Returns: Single-line formatted string.
    public static func formatCompact(
        _ statistics: SRTStatistics
    ) -> String {
        let rtt = formatDuration(statistics.rttMicroseconds)
        let bw = formatBitrate(statistics.bandwidthBitsPerSecond)
        let loss = String(format: "%.2f%%", statistics.lossRate * 100)
        return "RTT=\(rtt) BW=\(bw) Loss=\(loss) InFlight=\(statistics.packetsInFlight)"
    }

    /// Format a quality score with grade and bar.
    ///
    /// - Parameter quality: The connection quality to format.
    /// - Returns: Formatted quality string.
    public static func formatQuality(
        _ quality: SRTConnectionQuality
    ) -> String {
        let percent = Int(quality.score * 100)
        let barLength = percent / 5
        let bar =
            String(repeating: "#", count: barLength)
            + String(repeating: "-", count: 20 - barLength)
        return "Quality: \(quality.grade) [\(bar)] \(percent)%"
    }

    /// Format bytes as human-readable (B, KB, MB, GB).
    ///
    /// - Parameter bytes: Byte count.
    /// - Returns: Human-readable string.
    public static func formatBytes(_ bytes: UInt64) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        } else {
            return String(
                format: "%.1f GB", Double(bytes) / (1024 * 1024 * 1024))
        }
    }

    /// Format microseconds as human-readable duration.
    ///
    /// - Parameter microseconds: Duration in microseconds.
    /// - Returns: Human-readable string.
    public static func formatDuration(_ microseconds: UInt64) -> String {
        if microseconds < 1_000 {
            return "\(microseconds)us"
        } else if microseconds < 1_000_000 {
            return String(
                format: "%.1fms", Double(microseconds) / 1_000)
        } else if microseconds < 60_000_000 {
            return String(
                format: "%.1fs", Double(microseconds) / 1_000_000)
        } else {
            let totalSeconds = microseconds / 1_000_000
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            return "\(minutes)m \(seconds)s"
        }
    }

    /// Format bits/second as human-readable rate (bps, Kbps, Mbps, Gbps).
    ///
    /// - Parameter bps: Bits per second.
    /// - Returns: Human-readable string.
    public static func formatBitrate(_ bps: UInt64) -> String {
        if bps < 1_000 {
            return "\(bps) bps"
        } else if bps < 1_000_000 {
            return String(format: "%.1f Kbps", Double(bps) / 1_000)
        } else if bps < 1_000_000_000 {
            return String(format: "%.1f Mbps", Double(bps) / 1_000_000)
        } else {
            return String(
                format: "%.1f Gbps", Double(bps) / 1_000_000_000)
        }
    }
}
