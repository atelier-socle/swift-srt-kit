// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("Congestion Integration Tests")
struct CongestionIntegrationTests {
    // MARK: - LiveCC end-to-end

    @Test("100 packets through LiveCC + pacer: periods consistent")
    func liveCCPacerConsistent() {
        var cc = LiveCC(
            configuration: .init(
                mode: .direct(bitsPerSecond: 10_000_000),
                initialPayloadSize: 1316
            ))
        var pacer = PacketPacer()
        var currentTime: UInt64 = 1_000_000

        for _ in 0..<100 {
            let period = cc.sendingPeriod()
            let decision = pacer.canSend(currentTime: currentTime, sendingPeriod: period)
            if case .waitMicroseconds(let wait) = decision {
                currentTime += wait
            }
            pacer.packetSent(at: currentTime)
            cc.onPacketSent(payloadSize: 1316, timestamp: UInt32(currentTime & 0xFFFF_FFFF))
            currentTime += period
        }

        #expect(pacer.packetsSent == 100)
        // Period should be stable since payload size is constant
        #expect(cc.sendingPeriod() == 1065)
    }

    @Test("Change bandwidth mid-stream adjusts periods")
    func liveCCBandwidthChange() {
        var cc = LiveCC(
            configuration: .init(
                mode: .auto(overheadPercent: 25),
                initialPayloadSize: 1316
            ))
        cc.updateEstimatedBandwidth(10_000_000)
        let periodBefore = cc.sendingPeriod()

        cc.updateEstimatedBandwidth(100_000_000)
        let periodAfter = cc.sendingPeriod()

        #expect(periodAfter < periodBefore)
    }

    @Test("Auto mode + bandwidth estimation adapts")
    func autoModeBandwidthEstimation() {
        var cc = LiveCC(
            configuration: .init(
                mode: .auto(overheadPercent: 25),
                initialPayloadSize: 1316
            ))
        var estimator = BandwidthEstimator()

        // Simulate probe pairs
        estimator.recordProbePacket(
            packetSize: 1332, receiveTime: 1_000_000, isSecondOfPair: false)
        estimator.recordProbePacket(
            packetSize: 1332, receiveTime: 1_001_000, isSecondOfPair: true)

        cc.updateEstimatedBandwidth(estimator.estimatedBandwidth)
        #expect(cc.sendingPeriod() > 0)
    }

    // MARK: - FileCC end-to-end

    @Test("Slow start, ACKs grow cwnd, loss drops it")
    func fileCCSlowStartAndLoss() {
        var cc = FileCC(configuration: .init(initialCWND: 16))
        #expect(cc.phase == .slowStart)

        // Slow start: ACKs grow cwnd
        for _ in 0..<5 {
            cc.onACK(acknowledgedPackets: 10, rtt: 50_000, bandwidth: 0, availableBuffer: 1000)
        }
        let peakCwnd = cc.cwnd
        #expect(peakCwnd == 66)  // 16 + 5*10

        // Loss: drops cwnd
        cc.onNAK(lossCount: 3)
        #expect(cc.phase == .congestionAvoidance)
        #expect(cc.cwnd < peakCwnd)
        #expect(cc.cwnd == 57)  // 66 * 7 / 8 = 57
    }

    @Test("Recovery: cwnd slowly grows back after loss")
    func fileCCRecovery() {
        var cc = FileCC(configuration: .init(initialCWND: 100))
        cc.onNAK(lossCount: 1)  // cwnd = 87
        let afterLoss = cc.cwnd

        // Many ACKs to grow back
        for _ in 0..<1000 {
            cc.onACK(acknowledgedPackets: 1, rtt: 50_000, bandwidth: 0, availableBuffer: 1000)
        }
        #expect(cc.cwnd > afterLoss)
    }

    @Test("Sending window constrains with flow window")
    func fileCCSendingWindowConstrained() {
        let cc = FileCC(configuration: .init(initialCWND: 100))
        let window = cc.sendingWindow(flowWindowSize: 50, peerAvailableBuffer: 200)
        #expect(window == 50)
    }

    @Test("Multiple loss events: cwnd drops each time")
    func fileCCMultipleLoss() {
        var cc = FileCC(configuration: .init(initialCWND: 100))
        var cwndHistory: [Int] = [cc.cwnd]
        for _ in 0..<5 {
            cc.onNAK(lossCount: 1)
            cwndHistory.append(cc.cwnd)
        }
        // Each entry should be <= previous
        for i in 1..<cwndHistory.count {
            #expect(cwndHistory[i] <= cwndHistory[i - 1])
        }
        #expect(cc.lossEventCount == 5)
    }

    // MARK: - Cross-algorithm

    @Test("Factory creates correct type based on name")
    func factoryCorrectType() {
        let factory = CongestionControllerFactory.default
        let live = factory.create(name: "live")
        let file = factory.create(name: "file")
        #expect(live?.congestionWindow() == nil)  // LiveCC
        #expect(file?.congestionWindow() != nil)  // FileCC
    }

    @Test("LiveCC and FileCC produce different behaviors")
    func differentBehaviors() {
        var live = LiveCC(
            configuration: .init(
                mode: .direct(bitsPerSecond: 10_000_000)
            ))
        var file = FileCC()

        let livePeriodBefore = live.sendingPeriod()
        let fileCwndBefore = file.cwnd

        // Same events
        live.onNAK(lossCount: 5)
        file.onNAK(lossCount: 5)

        // Live: no change
        #expect(live.sendingPeriod() == livePeriodBefore)
        // File: cwnd decreased
        #expect(file.cwnd < fileCwndBefore)
    }

    @Test("FileCC additive increase accumulates correctly over RTT")
    func fileCCAdditiveIncrease() {
        var cc = FileCC(configuration: .init(initialCWND: 50))
        cc.onNAK(lossCount: 1)  // Enter CA: 50 * 7/8 = 43
        let startCwnd = cc.cwnd
        #expect(startCwnd == 43)

        // Simulate 1 RTT worth of single-packet ACKs
        for _ in 0..<startCwnd {
            cc.onACK(acknowledgedPackets: 1, rtt: 50_000, bandwidth: 0, availableBuffer: 1000)
        }
        // Should increment by 1 after cwnd ACKs
        #expect(cc.cwnd == startCwnd + 1)
    }
}
