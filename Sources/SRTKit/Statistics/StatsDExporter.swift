// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// StatsD format exporter for real-time dashboards.
///
/// Generates metrics in StatsD wire format suitable for
/// UDP push to StatsD/Datadog/Graphite.
public struct StatsDExporter: MetricsExporter, Sendable {
    /// Metric prefix (default: "srt").
    public let prefix: String

    /// Create a StatsD exporter.
    ///
    /// - Parameter prefix: Metric name prefix.
    public init(prefix: String = "srt") {
        self.prefix = prefix
    }

    /// Format name for logging.
    public var formatName: String { "statsd" }

    /// Export statistics as StatsD format bytes.
    public func export(
        _ statistics: SRTStatistics, labels: [String: String]
    ) -> [UInt8] {
        Array(render(statistics, labels: labels).utf8)
    }

    /// Render statistics as StatsD format string.
    ///
    /// - Parameters:
    ///   - statistics: The statistics snapshot.
    ///   - labels: Key-value labels (exported as Datadog-style tags).
    /// - Returns: StatsD format string.
    public func render(
        _ statistics: SRTStatistics, labels: [String: String]
    ) -> String {
        let tagStr = formatTags(labels)
        var lines: [String] = []

        // Counters
        appendCounter(&lines, "packets_sent", statistics.packetsSent, tagStr)
        appendCounter(&lines, "packets_received", statistics.packetsReceived, tagStr)
        appendCounter(
            &lines, "packets_lost", statistics.packetsSentLost + statistics.packetsReceivedLost,
            tagStr)
        appendCounter(&lines, "packets_retransmitted", statistics.packetsRetransmitted, tagStr)
        appendCounter(&lines, "packets_dropped", statistics.packetsDropped, tagStr)
        appendCounter(&lines, "packets_fec_recovered", statistics.packetsFECRecovered, tagStr)
        appendCounter(&lines, "packets_duplicate", statistics.packetsDuplicate, tagStr)
        appendCounter(&lines, "acks_sent", statistics.acksSent, tagStr)
        appendCounter(&lines, "naks_sent", statistics.naksSent, tagStr)
        appendCounter(&lines, "bytes_sent", statistics.bytesSent, tagStr)
        appendCounter(&lines, "bytes_received", statistics.bytesReceived, tagStr)

        // Gauges
        appendGauge(&lines, "rtt_us", statistics.rttMicroseconds, tagStr)
        appendGauge(&lines, "rtt_variance_us", statistics.rttVarianceMicroseconds, tagStr)
        appendGauge(&lines, "bandwidth_bps", statistics.bandwidthBitsPerSecond, tagStr)
        appendGauge(&lines, "send_rate_bps", statistics.sendRateBitsPerSecond, tagStr)
        appendGauge(&lines, "receive_rate_bps", statistics.receiveRateBitsPerSecond, tagStr)
        appendGauge(&lines, "send_buffer_pkts", UInt64(statistics.sendBufferPackets), tagStr)
        appendGauge(
            &lines, "receive_buffer_pkts", UInt64(statistics.receiveBufferPackets), tagStr)
        appendGauge(
            &lines, "congestion_window_pkts", UInt64(statistics.congestionWindowPackets), tagStr)
        appendGauge(&lines, "packets_in_flight", UInt64(statistics.packetsInFlight), tagStr)

        let quality = SRTConnectionQuality.from(statistics: statistics)
        appendGaugeDouble(&lines, "quality_score", quality.score, tagStr)

        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Private

    private func formatTags(_ labels: [String: String]) -> String {
        guard !labels.isEmpty else { return "" }
        let sorted = labels.sorted { $0.key < $1.key }
        let tags = sorted.map { "\($0.key):\($0.value)" }
        return "|#\(tags.joined(separator: ","))"
    }

    private func appendCounter(
        _ lines: inout [String], _ name: String, _ value: UInt64, _ tags: String
    ) {
        lines.append("\(prefix).\(name):\(value)|c\(tags)")
    }

    private func appendGauge(
        _ lines: inout [String], _ name: String, _ value: UInt64, _ tags: String
    ) {
        lines.append("\(prefix).\(name):\(value)|g\(tags)")
    }

    private func appendGaugeDouble(
        _ lines: inout [String], _ name: String, _ value: Double, _ tags: String
    ) {
        let formatted = formatDouble(value)
        lines.append("\(prefix).\(name):\(formatted)|g\(tags)")
    }

    private func formatDouble(_ value: Double) -> String {
        let intPart = Int(value)
        let fracPart = Int((value - Double(intPart)) * 100)
        if fracPart == 0 {
            return "\(intPart)"
        }
        let absFrac = fracPart < 0 ? -fracPart : fracPart
        if absFrac < 10 {
            return "\(intPart).0\(absFrac)"
        }
        return "\(intPart).\(absFrac)"
    }
}
