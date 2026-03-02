// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("PrometheusExporter Tests")
struct PrometheusExporterTests {
    @Test("Default prefix is srt")
    func defaultPrefix() {
        let exporter = PrometheusExporter()
        #expect(exporter.prefix == "srt")
    }

    @Test("Custom prefix works")
    func customPrefix() {
        let exporter = PrometheusExporter(prefix: "myapp_srt")
        let output = exporter.render(SRTStatistics(), labels: [:])
        #expect(output.contains("myapp_srt_"))
    }

    @Test("formatName is prometheus")
    func formatName() {
        let exporter = PrometheusExporter()
        #expect(exporter.formatName == "prometheus")
    }

    @Test("Counter metrics have _total suffix")
    func counterTotalSuffix() {
        let exporter = PrometheusExporter()
        let stats = SRTStatistics(packetsSent: 12345)
        let output = exporter.render(stats, labels: [:])
        #expect(output.contains("srt_packets_sent_total 12345"))
    }

    @Test("Gauge metrics have no suffix")
    func gaugeNoSuffix() {
        let exporter = PrometheusExporter()
        let stats = SRTStatistics(rttMicroseconds: 45000)
        let output = exporter.render(stats, labels: [:])
        #expect(output.contains("srt_rtt_microseconds 45000"))
    }

    @Test("Labels formatted correctly")
    func labelsFormatted() {
        let exporter = PrometheusExporter()
        let stats = SRTStatistics(packetsSent: 100)
        let output = exporter.render(stats, labels: ["connection": "caller1"])
        #expect(output.contains("{connection=\"caller1\"}"))
    }

    @Test("Multiple labels comma-separated")
    func multipleLabels() {
        let exporter = PrometheusExporter()
        let stats = SRTStatistics()
        let output = exporter.render(stats, labels: ["a": "1", "b": "2"])
        #expect(output.contains("a=\"1\",b=\"2\""))
    }

    @Test("Empty labels produce no braces")
    func emptyLabels() {
        let exporter = PrometheusExporter()
        let stats = SRTStatistics(packetsSent: 5)
        let output = exporter.render(stats, labels: [:])
        #expect(output.contains("srt_packets_sent_total 5"))
        #expect(!output.contains("{}"))
    }

    @Test("Bandwidth exported in bps")
    func bandwidthExported() {
        let exporter = PrometheusExporter()
        let stats = SRTStatistics(bandwidthBitsPerSecond: 5_000_000)
        let output = exporter.render(stats, labels: [:])
        #expect(output.contains("srt_bandwidth_bps 5000000"))
    }

    @Test("HELP and TYPE comments present")
    func helpTypeComments() {
        let exporter = PrometheusExporter()
        let output = exporter.render(SRTStatistics(), labels: [:])
        #expect(output.contains("# HELP"))
        #expect(output.contains("# TYPE"))
        #expect(output.contains("counter"))
        #expect(output.contains("gauge"))
    }

    @Test("export returns valid UTF-8 bytes")
    func exportValidUTF8() {
        let exporter = PrometheusExporter()
        let bytes = exporter.export(SRTStatistics(), labels: ["test": "value"])
        let text = String(decoding: bytes, as: UTF8.self)
        #expect(!text.isEmpty)
        #expect(text.contains("srt_"))
    }

    @Test("Quality score exported")
    func qualityScoreExported() {
        let exporter = PrometheusExporter()
        let stats = SRTStatistics()
        let output = exporter.render(stats, labels: [:])
        #expect(output.contains("srt_connection_quality_score"))
    }
}
