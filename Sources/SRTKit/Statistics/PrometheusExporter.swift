// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Prometheus text exposition format exporter.
///
/// Generates metrics in the Prometheus text format suitable for
/// scraping by Prometheus or compatible systems.
public struct PrometheusExporter: MetricsExporter, Sendable {
    /// Metric prefix (default: "srt").
    public let prefix: String

    /// Create a Prometheus exporter.
    ///
    /// - Parameter prefix: Metric name prefix.
    public init(prefix: String = "srt") {
        self.prefix = prefix
    }

    /// Format name for logging.
    public var formatName: String { "prometheus" }

    /// Export statistics as Prometheus text format bytes.
    public func export(
        _ statistics: SRTStatistics, labels: [String: String]
    ) -> [UInt8] {
        Array(render(statistics, labels: labels).utf8)
    }

    /// Render statistics as a Prometheus text format string.
    ///
    /// - Parameters:
    ///   - statistics: The statistics snapshot.
    ///   - labels: Key-value labels.
    /// - Returns: Prometheus text format string.
    public func render(
        _ statistics: SRTStatistics, labels: [String: String]
    ) -> String {
        let labelStr = formatLabels(labels)
        var lines: [String] = []

        // Counters (with _total suffix)
        appendCounter(
            &lines, "packets_sent", statistics.packetsSent, labelStr)
        appendCounter(
            &lines, "packets_received", statistics.packetsReceived, labelStr)
        appendCounter(
            &lines, "packets_lost", statistics.packetsSentLost + statistics.packetsReceivedLost,
            labelStr)
        appendCounter(
            &lines, "packets_retransmitted", statistics.packetsRetransmitted, labelStr)
        appendCounter(
            &lines, "packets_dropped", statistics.packetsDropped, labelStr)
        appendCounter(
            &lines, "packets_fec_recovered", statistics.packetsFECRecovered, labelStr)
        appendCounter(
            &lines, "packets_duplicate", statistics.packetsDuplicate, labelStr)
        appendCounter(
            &lines, "acks_sent", statistics.acksSent, labelStr)
        appendCounter(
            &lines, "naks_sent", statistics.naksSent, labelStr)
        appendCounter(
            &lines, "bytes_sent", statistics.bytesSent, labelStr)
        appendCounter(
            &lines, "bytes_received", statistics.bytesReceived, labelStr)
        appendCounter(
            &lines, "bytes_retransmitted", statistics.bytesRetransmitted, labelStr)
        appendCounter(
            &lines, "bytes_dropped", statistics.bytesDropped, labelStr)
        appendCounter(
            &lines, "key_rotations", statistics.keyRotations, labelStr)
        appendCounter(
            &lines, "fec_packets_sent", statistics.fecPacketsSent, labelStr)
        appendCounter(
            &lines, "fec_packets_received", statistics.fecPacketsReceived, labelStr)

        // Gauges
        appendGauge(
            &lines, "rtt_microseconds", statistics.rttMicroseconds, labelStr)
        appendGauge(
            &lines, "rtt_variance_microseconds", statistics.rttVarianceMicroseconds, labelStr)
        appendGauge(
            &lines, "bandwidth_bps", statistics.bandwidthBitsPerSecond, labelStr)
        appendGauge(
            &lines, "send_rate_bps", statistics.sendRateBitsPerSecond, labelStr)
        appendGauge(
            &lines, "receive_rate_bps", statistics.receiveRateBitsPerSecond, labelStr)
        appendGauge(
            &lines, "send_buffer_packets", UInt64(statistics.sendBufferPackets), labelStr)
        appendGauge(
            &lines, "receive_buffer_packets", UInt64(statistics.receiveBufferPackets), labelStr)
        appendGauge(
            &lines, "congestion_window_packets", UInt64(statistics.congestionWindowPackets),
            labelStr)
        appendGauge(
            &lines, "packets_in_flight", UInt64(statistics.packetsInFlight), labelStr)

        let quality = SRTConnectionQuality.from(statistics: statistics)
        appendGaugeDouble(
            &lines, "connection_quality_score", quality.score, labelStr)

        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Private

    private func formatLabels(_ labels: [String: String]) -> String {
        guard !labels.isEmpty else { return "" }
        let sorted = labels.sorted { $0.key < $1.key }
        let pairs = sorted.map { "\($0.key)=\"\($0.value)\"" }
        return "{\(pairs.joined(separator: ","))}"
    }

    private func appendCounter(
        _ lines: inout [String], _ name: String, _ value: UInt64, _ labels: String
    ) {
        let fullName = "\(prefix)_\(name)_total"
        lines.append("# HELP \(fullName) Total \(name.replacingOccurrences(of: "_", with: " ")).")
        lines.append("# TYPE \(fullName) counter")
        lines.append("\(fullName)\(labels) \(value)")
    }

    private func appendGauge(
        _ lines: inout [String], _ name: String, _ value: UInt64, _ labels: String
    ) {
        let fullName = "\(prefix)_\(name)"
        lines.append("# TYPE \(fullName) gauge")
        lines.append("\(fullName)\(labels) \(value)")
    }

    private func appendGaugeDouble(
        _ lines: inout [String], _ name: String, _ value: Double, _ labels: String
    ) {
        let fullName = "\(prefix)_\(name)"
        lines.append("# TYPE \(fullName) gauge")
        let formatted = formatDouble(value)
        lines.append("\(fullName)\(labels) \(formatted)")
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

// MARK: - String helpers (no Foundation)

extension String {
    func replacingOccurrences(of target: String, with replacement: String) -> String {
        let targetChars = Array(target)
        let resultChars = Array(self)
        var output: [Character] = []
        var i = 0
        while i < resultChars.count {
            if i + targetChars.count <= resultChars.count {
                let slice = Array(resultChars[i..<i + targetChars.count])
                if slice == targetChars {
                    output.append(contentsOf: replacement)
                    i += targetChars.count
                    continue
                }
            }
            output.append(resultChars[i])
            i += 1
        }
        return String(output)
    }
}
