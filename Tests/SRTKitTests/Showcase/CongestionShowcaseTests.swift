// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("Congestion Control Showcase")
struct CongestionShowcaseTests {
    // MARK: - LiveCC

    @Test("LiveCC pacing period from bandwidth")
    func liveCCPacing() {
        let config = LiveCC.Configuration(
            mode: .direct(bitsPerSecond: 10_000_000),
            initialPayloadSize: 1316)
        var liveCC = LiveCC(configuration: config)

        // Sending period = payloadSize * 8 / bandwidth
        let period = liveCC.sendingPeriod()
        #expect(period > 0)

        // After sending a packet, average payload updates
        liveCC.onPacketSent(payloadSize: 1316, timestamp: 0)
        #expect(liveCC.averagePayloadSize > 0)
    }

    @Test("LiveCC updates bandwidth on ACK")
    func liveCCBandwidthUpdate() {
        var liveCC = LiveCC()
        liveCC.onACK(
            acknowledgedPackets: 10,
            rtt: 20_000,
            bandwidth: 8_000_000,
            availableBuffer: 100)
        liveCC.updateEstimatedBandwidth(8_000_000)
        #expect(liveCC.estimatedBandwidth > 0)
    }

    // MARK: - FileCC

    @Test("FileCC AIMD: slow start then congestion avoidance")
    func fileCCAIMD() {
        var fileCC = FileCC(
            configuration: .init(initialCWND: 16, minimumCWND: 2))

        // Starts in slow start
        #expect(fileCC.phase == .slowStart)
        #expect(fileCC.cwnd == 16)

        // ACKs grow window exponentially in slow start
        fileCC.onACK(
            acknowledgedPackets: 16,
            rtt: 20_000,
            bandwidth: 10_000_000,
            availableBuffer: 100)
        #expect(fileCC.cwnd > 16)

        // Loss triggers multiplicative decrease → congestion avoidance
        fileCC.onNAK(lossCount: 5)
        #expect(fileCC.phase == .congestionAvoidance)
        #expect(fileCC.lossEventCount == 1)
    }

    // MARK: - BandwidthEstimator

    @Test("BandwidthEstimator produces estimate from probe pairs")
    func bandwidthEstimation() {
        var estimator = BandwidthEstimator()

        // Feed probe packet pairs
        for i: UInt64 in 0..<20 {
            estimator.recordProbePacket(
                packetSize: 1316,
                receiveTime: i * 1000,
                isSecondOfPair: i % 2 == 1)
        }

        #expect(estimator.estimateCount > 0)
    }

    // MARK: - PacketPacer

    @Test("PacketPacer enforces sending interval")
    func packetPacing() {
        var pacer = PacketPacer()
        let sendingPeriod: UInt64 = 1000  // 1ms between packets

        // First packet can always be sent
        let first = pacer.canSend(
            currentTime: 0, sendingPeriod: sendingPeriod)
        #expect(first == .sendNow)
        pacer.packetSent(at: 0)

        // Immediately after — should wait
        let second = pacer.canSend(
            currentTime: 500, sendingPeriod: sendingPeriod)
        if case .waitMicroseconds(let wait) = second {
            #expect(wait > 0)
        }

        // After full period — can send
        let third = pacer.canSend(
            currentTime: 1000, sendingPeriod: sendingPeriod)
        #expect(third == .sendNow)
    }

    @Test("PacketPacer identifies probe packets")
    func probePackets() {
        var pacer = PacketPacer()
        for _ in 0..<16 {
            pacer.packetSent(at: 0)
        }
        // Every probeInterval-th packet is a probe
        #expect(pacer.isProbePacket(probeInterval: 16))
    }
}
