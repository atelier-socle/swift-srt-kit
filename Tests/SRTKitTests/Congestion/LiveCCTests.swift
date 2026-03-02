// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("LiveCC Tests")
struct LiveCCTests {
    // MARK: - Name

    @Test("Name is live")
    func name() {
        let cc = LiveCC()
        #expect(cc.name == "live")
    }

    // MARK: - Pacing

    @Test("Default sending period is non-zero")
    func defaultPeriodNonZero() {
        let cc = LiveCC()
        #expect(cc.sendingPeriod() > 0)
    }

    @Test("Direct mode 1 Gbps, 1316-byte payload sending period")
    func directMode1Gbps() {
        let cc = LiveCC(
            configuration: .init(
                mode: .direct(bitsPerSecond: 125_000_000),
                initialPayloadSize: 1316
            ))
        // (1316 + 16) * 8 * 1_000_000 / 125_000_000
        // = 1332 * 8_000_000 / 125_000_000
        // = 10_656_000_000 / 125_000_000
        // = 85
        #expect(cc.sendingPeriod() == 85)
    }

    @Test("Lower bandwidth produces longer sending period")
    func lowerBandwidthLongerPeriod() {
        let high = LiveCC(
            configuration: .init(
                mode: .direct(bitsPerSecond: 100_000_000)
            ))
        let low = LiveCC(
            configuration: .init(
                mode: .direct(bitsPerSecond: 10_000_000)
            ))
        #expect(low.sendingPeriod() > high.sendingPeriod())
    }

    @Test("Higher bandwidth produces shorter sending period")
    func higherBandwidthShorterPeriod() {
        let base = LiveCC(
            configuration: .init(
                mode: .direct(bitsPerSecond: 10_000_000)
            ))
        let fast = LiveCC(
            configuration: .init(
                mode: .direct(bitsPerSecond: 100_000_000)
            ))
        #expect(fast.sendingPeriod() < base.sendingPeriod())
    }

    @Test("Sending period at 10 Mbps with 1316 payload")
    func periodAt10Mbps() {
        let cc = LiveCC(
            configuration: .init(
                mode: .direct(bitsPerSecond: 10_000_000),
                initialPayloadSize: 1316
            ))
        // (1316 + 16) * 8 * 1_000_000 / 10_000_000
        // = 1332 * 8_000_000 / 10_000_000
        // = 10_656_000_000 / 10_000_000
        // = 1065
        #expect(cc.sendingPeriod() == 1065)
    }

    // MARK: - EWMA

    @Test("Initial averagePayloadSize equals initialPayloadSize")
    func initialPayloadSize() {
        let cc = LiveCC(configuration: .init(initialPayloadSize: 1316))
        #expect(cc.averagePayloadSize == 1316)
    }

    @Test("After one packet: EWMA updates")
    func ewmaOnePacket() {
        var cc = LiveCC(configuration: .init(initialPayloadSize: 1316))
        cc.onPacketSent(payloadSize: 500, timestamp: 0)
        // (7 * 1316 + 500) / 8 = (9212 + 500) / 8 = 9712 / 8 = 1214
        #expect(cc.averagePayloadSize == 1214)
    }

    @Test("EWMA converges toward consistent payload size")
    func ewmaConverges() {
        var cc = LiveCC(configuration: .init(initialPayloadSize: 1316))
        for _ in 0..<100 {
            cc.onPacketSent(payloadSize: 1000, timestamp: 0)
        }
        // After many 1000-byte packets, should converge to ~1000
        #expect(cc.averagePayloadSize >= 999 && cc.averagePayloadSize <= 1001)
    }

    @Test("Small packets bring average down gradually")
    func ewmaSmallPackets() {
        var cc = LiveCC(configuration: .init(initialPayloadSize: 1316))
        let before = cc.averagePayloadSize
        cc.onPacketSent(payloadSize: 100, timestamp: 0)
        #expect(cc.averagePayloadSize < before)
        #expect(cc.averagePayloadSize > 100)  // Gradual, not instant
    }

    @Test("Large packets bring average up gradually")
    func ewmaLargePackets() {
        var cc = LiveCC(configuration: .init(initialPayloadSize: 500))
        let before = cc.averagePayloadSize
        cc.onPacketSent(payloadSize: 2000, timestamp: 0)
        #expect(cc.averagePayloadSize > before)
        #expect(cc.averagePayloadSize < 2000)  // Gradual, not instant
    }

    @Test("Sending period updates after onPacketSent")
    func periodUpdatesAfterSend() {
        var cc = LiveCC(
            configuration: .init(
                mode: .direct(bitsPerSecond: 10_000_000),
                initialPayloadSize: 1316
            ))
        let before = cc.sendingPeriod()
        // Send a much smaller packet to change the average
        for _ in 0..<50 {
            cc.onPacketSent(payloadSize: 100, timestamp: 0)
        }
        let after = cc.sendingPeriod()
        #expect(after < before)
    }

    // MARK: - No window

    @Test("congestionWindow returns nil")
    func noWindow() {
        let cc = LiveCC()
        #expect(cc.congestionWindow() == nil)
    }

    @Test("sendingWindow returns flowWindowSize")
    func sendingWindowIsFlowWindow() {
        let cc = LiveCC()
        #expect(cc.sendingWindow(flowWindowSize: 8192, peerAvailableBuffer: 100) == 8192)
    }

    // MARK: - Event no-ops

    @Test("onACK does not change sending period")
    func ackNoOp() {
        var cc = LiveCC(
            configuration: .init(
                mode: .direct(bitsPerSecond: 10_000_000)
            ))
        let before = cc.sendingPeriod()
        cc.onACK(acknowledgedPackets: 100, rtt: 50_000, bandwidth: 1000, availableBuffer: 500)
        #expect(cc.sendingPeriod() == before)
    }

    @Test("onNAK does not change sending period")
    func nakNoOp() {
        var cc = LiveCC(
            configuration: .init(
                mode: .direct(bitsPerSecond: 10_000_000)
            ))
        let before = cc.sendingPeriod()
        cc.onNAK(lossCount: 10)
        #expect(cc.sendingPeriod() == before)
    }

    @Test("onTimeout does not change sending period")
    func timeoutNoOp() {
        var cc = LiveCC(
            configuration: .init(
                mode: .direct(bitsPerSecond: 10_000_000)
            ))
        let before = cc.sendingPeriod()
        cc.onTimeout()
        #expect(cc.sendingPeriod() == before)
    }

    // MARK: - Auto mode

    @Test("updateEstimatedBandwidth changes period in auto mode")
    func autoModeUpdate() {
        var cc = LiveCC(
            configuration: .init(
                mode: .auto(overheadPercent: 25),
                initialPayloadSize: 1316
            ))
        // Initially estimatedBW = 0, so period = 0 (maxBW = 0)
        #expect(cc.sendingPeriod() == 0)

        cc.updateEstimatedBandwidth(10_000_000)
        // Now maxBW = 10_000_000 * 1.25 = 12_500_000
        #expect(cc.sendingPeriod() > 0)
    }

    @Test("Auto mode period recalculates when bandwidth changes")
    func autoModePeriodChanges() {
        var cc = LiveCC(
            configuration: .init(
                mode: .auto(overheadPercent: 25),
                initialPayloadSize: 1316
            ))
        cc.updateEstimatedBandwidth(10_000_000)
        let periodLow = cc.sendingPeriod()

        cc.updateEstimatedBandwidth(100_000_000)
        let periodHigh = cc.sendingPeriod()

        #expect(periodHigh < periodLow)
    }

    // MARK: - Estimated bandwidth

    @Test("estimatedBandwidth initially zero")
    func estimatedBandwidthInitial() {
        let cc = LiveCC()
        #expect(cc.estimatedBandwidth == 0)
    }
}
