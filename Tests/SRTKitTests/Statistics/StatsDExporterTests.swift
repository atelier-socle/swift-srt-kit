// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("StatsDExporter Tests")
struct StatsDExporterTests {
    @Test("Default prefix is srt")
    func defaultPrefix() {
        let exporter = StatsDExporter()
        #expect(exporter.prefix == "srt")
    }

    @Test("Custom prefix works")
    func customPrefix() {
        let exporter = StatsDExporter(prefix: "myapp")
        let output = exporter.render(SRTStatistics(), labels: [:])
        #expect(output.contains("myapp."))
    }

    @Test("formatName is statsd")
    func formatName() {
        let exporter = StatsDExporter()
        #expect(exporter.formatName == "statsd")
    }

    @Test("Counter format uses |c")
    func counterFormat() {
        let exporter = StatsDExporter()
        let stats = SRTStatistics(packetsSent: 12345)
        let output = exporter.render(stats, labels: [:])
        #expect(output.contains("srt.packets_sent:12345|c"))
    }

    @Test("Gauge format uses |g")
    func gaugeFormat() {
        let exporter = StatsDExporter()
        let stats = SRTStatistics(rttMicroseconds: 45000)
        let output = exporter.render(stats, labels: [:])
        #expect(output.contains("srt.rtt_us:45000|g"))
    }

    @Test("Labels exported as Datadog-style tags")
    func labelsAsTags() {
        let exporter = StatsDExporter()
        let stats = SRTStatistics(packetsSent: 100)
        let output = exporter.render(stats, labels: ["connection": "caller1"])
        #expect(output.contains("|#connection:caller1"))
    }

    @Test("Multiple tags comma-separated")
    func multipleTags() {
        let exporter = StatsDExporter()
        let stats = SRTStatistics()
        let output = exporter.render(stats, labels: ["a": "1", "b": "2"])
        #expect(output.contains("|#a:1,b:2"))
    }

    @Test("Empty labels produce no tag suffix")
    func emptyLabelsNoTags() {
        let exporter = StatsDExporter()
        let stats = SRTStatistics(packetsSent: 5)
        let output = exporter.render(stats, labels: [:])
        #expect(output.contains("srt.packets_sent:5|c"))
        #expect(!output.contains("|#"))
    }

    @Test("Bandwidth exported as gauge")
    func bandwidthGauge() {
        let exporter = StatsDExporter()
        let stats = SRTStatistics(bandwidthBitsPerSecond: 5_000_000)
        let output = exporter.render(stats, labels: [:])
        #expect(output.contains("srt.bandwidth_bps:5000000|g"))
    }

    @Test("Quality score exported as gauge")
    func qualityScoreGauge() {
        let exporter = StatsDExporter()
        let output = exporter.render(SRTStatistics(), labels: [:])
        #expect(output.contains("srt.quality_score:"))
        #expect(output.contains("|g"))
    }

    @Test("export returns valid UTF-8 bytes")
    func exportValidUTF8() {
        let exporter = StatsDExporter()
        let bytes = exporter.export(SRTStatistics(), labels: ["test": "value"])
        let text = String(decoding: bytes, as: UTF8.self)
        #expect(!text.isEmpty)
        #expect(text.contains("srt."))
    }
}
