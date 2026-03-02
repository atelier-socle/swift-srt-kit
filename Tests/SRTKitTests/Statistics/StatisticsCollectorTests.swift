// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("StatisticsCollector Tests")
struct StatisticsCollectorTests {
    // MARK: - Counter recording

    @Test("recordPacketSent increments packetsSent and bytesSent")
    func recordPacketSent() {
        var collector = StatisticsCollector()
        collector.recordPacketSent(payloadSize: 1316)
        let stats = collector.snapshot(at: 1000)
        #expect(stats.packetsSent == 1)
        #expect(stats.bytesSent == 1316)
    }

    @Test("recordPacketReceived increments packetsReceived and bytesReceived")
    func recordPacketReceived() {
        var collector = StatisticsCollector()
        collector.recordPacketReceived(payloadSize: 1316)
        let stats = collector.snapshot(at: 1000)
        #expect(stats.packetsReceived == 1)
        #expect(stats.bytesReceived == 1316)
    }

    @Test("recordPacketLost increments packetsSentLost")
    func recordPacketLost() {
        var collector = StatisticsCollector()
        collector.recordPacketLost()
        collector.recordPacketLost()
        let stats = collector.snapshot(at: 1000)
        #expect(stats.packetsSentLost == 2)
    }

    @Test("recordReceiveLoss increments packetsReceivedLost")
    func recordReceiveLoss() {
        var collector = StatisticsCollector()
        collector.recordReceiveLoss()
        let stats = collector.snapshot(at: 1000)
        #expect(stats.packetsReceivedLost == 1)
    }

    @Test("recordRetransmission increments both count and bytes")
    func recordRetransmission() {
        var collector = StatisticsCollector()
        collector.recordRetransmission(payloadSize: 1000)
        let stats = collector.snapshot(at: 1000)
        #expect(stats.packetsRetransmitted == 1)
        #expect(stats.bytesRetransmitted == 1000)
    }

    @Test("recordACKSent and recordNAKSent increment counts")
    func recordACKNAK() {
        var collector = StatisticsCollector()
        collector.recordACKSent()
        collector.recordACKSent()
        collector.recordNAKSent()
        let stats = collector.snapshot(at: 1000)
        #expect(stats.acksSent == 2)
        #expect(stats.naksSent == 1)
    }

    @Test("recordPacketDropped increments count and bytes")
    func recordPacketDropped() {
        var collector = StatisticsCollector()
        collector.recordPacketDropped(payloadSize: 500)
        let stats = collector.snapshot(at: 1000)
        #expect(stats.packetsDropped == 1)
        #expect(stats.bytesDropped == 500)
    }

    @Test("recordFECRecovery increments packetsFECRecovered")
    func recordFECRecovery() {
        var collector = StatisticsCollector()
        collector.recordFECRecovery()
        collector.recordFECRecovery()
        collector.recordFECRecovery()
        let stats = collector.snapshot(at: 1000)
        #expect(stats.packetsFECRecovered == 3)
    }

    @Test("recordDuplicate increments packetsDuplicate")
    func recordDuplicate() {
        var collector = StatisticsCollector()
        collector.recordDuplicate()
        let stats = collector.snapshot(at: 1000)
        #expect(stats.packetsDuplicate == 1)
    }

    @Test("recordKeyRotation updates keyRotations and currentKeyIndex")
    func recordKeyRotation() {
        var collector = StatisticsCollector()
        collector.recordKeyRotation(newIndex: 1)
        collector.recordKeyRotation(newIndex: 0)
        let stats = collector.snapshot(at: 1000)
        #expect(stats.keyRotations == 2)
        #expect(stats.currentKeyIndex == 0)
    }

    @Test("recordFECPacketSent and recordFECPacketReceived increment counts")
    func recordFECPackets() {
        var collector = StatisticsCollector()
        collector.recordFECPacketSent()
        collector.recordFECPacketSent()
        collector.recordFECPacketReceived()
        let stats = collector.snapshot(at: 1000)
        #expect(stats.fecPacketsSent == 2)
        #expect(stats.fecPacketsReceived == 1)
    }

    // MARK: - Metric updates

    @Test("updateTiming sets RTT values")
    func updateTiming() {
        var collector = StatisticsCollector()
        collector.updateTiming(
            rttMicroseconds: 45000,
            rttVarianceMicroseconds: 5000)
        let stats = collector.snapshot(at: 1000)
        #expect(stats.rttMicroseconds == 45000)
        #expect(stats.rttVarianceMicroseconds == 5000)
    }

    @Test("updateBandwidth sets all bandwidth fields")
    func updateBandwidth() {
        var collector = StatisticsCollector()
        collector.updateBandwidth(
            estimatedBitsPerSecond: 5_000_000,
            sendRateBitsPerSecond: 4_000_000,
            receiveRateBitsPerSecond: 3_000_000,
            maxBandwidthBitsPerSecond: 10_000_000)
        let stats = collector.snapshot(at: 1000)
        #expect(stats.bandwidthBitsPerSecond == 5_000_000)
        #expect(stats.sendRateBitsPerSecond == 4_000_000)
        #expect(stats.receiveRateBitsPerSecond == 3_000_000)
        #expect(stats.maxBandwidthBitsPerSecond == 10_000_000)
    }

    @Test("updateBuffers sets all buffer fields")
    func updateBuffers() {
        var collector = StatisticsCollector()
        collector.updateBuffers(
            sendBufferPackets: 100,
            sendBufferCapacity: 4096,
            receiveBufferPackets: 50,
            receiveBufferCapacity: 4096,
            flowWindowAvailable: 12800)
        let stats = collector.snapshot(at: 1000)
        #expect(stats.sendBufferPackets == 100)
        #expect(stats.sendBufferCapacity == 4096)
        #expect(stats.receiveBufferPackets == 50)
        #expect(stats.receiveBufferCapacity == 4096)
        #expect(stats.flowWindowAvailable == 12800)
    }

    @Test("updateCongestion sets congestion fields")
    func updateCongestion() {
        var collector = StatisticsCollector()
        collector.updateCongestion(
            windowPackets: 1000,
            sendingPeriodMicroseconds: 10000,
            packetsInFlight: 50)
        let stats = collector.snapshot(at: 1000)
        #expect(stats.congestionWindowPackets == 1000)
        #expect(stats.sendingPeriodMicroseconds == 10000)
        #expect(stats.packetsInFlight == 50)
    }

    // MARK: - Snapshots

    @Test("snapshot returns correct accumulated values")
    func snapshotAccumulated() {
        var collector = StatisticsCollector()
        collector.recordPacketSent(payloadSize: 100)
        collector.recordPacketSent(payloadSize: 200)
        collector.recordPacketReceived(payloadSize: 150)
        let stats = collector.snapshot(at: 5000)
        #expect(stats.packetsSent == 2)
        #expect(stats.bytesSent == 300)
        #expect(stats.packetsReceived == 1)
        #expect(stats.snapshotTimestamp == 5000)
    }

    @Test("snapshotAndReset returns values then resets counters")
    func snapshotAndReset() {
        var collector = StatisticsCollector()
        collector.recordPacketSent(payloadSize: 100)
        collector.recordPacketReceived(payloadSize: 200)
        collector.recordPacketLost()

        let first = collector.snapshotAndReset(at: 5000)
        #expect(first.packetsSent == 1)
        #expect(first.packetsReceived == 1)
        #expect(first.packetsSentLost == 1)

        let second = collector.snapshot(at: 10000)
        #expect(second.packetsSent == 0)
        #expect(second.packetsReceived == 0)
        #expect(second.packetsSentLost == 0)
    }

    @Test("uptimeMicroseconds calculated from start time")
    func uptimeFromStartTime() {
        var collector = StatisticsCollector()
        collector.setStartTime(1000)
        let stats = collector.snapshot(at: 5000)
        #expect(stats.uptimeMicroseconds == 4000)
    }
}
