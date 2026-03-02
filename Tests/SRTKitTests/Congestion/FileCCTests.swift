// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("FileCC Tests")
struct FileCCTests {
    // MARK: - Name

    @Test("Name is file")
    func name() {
        let cc = FileCC()
        #expect(cc.name == "file")
    }

    // MARK: - Slow start

    @Test("Initial cwnd equals configured value")
    func initialCWND() {
        let cc = FileCC()
        #expect(cc.cwnd == 16)
    }

    @Test("Initial phase is slowStart")
    func initialPhase() {
        let cc = FileCC()
        #expect(cc.phase == .slowStart)
    }

    @Test("onACK increases cwnd by acknowledgedPackets in slow start")
    func slowStartACK() {
        var cc = FileCC()
        cc.onACK(acknowledgedPackets: 5, rtt: 50_000, bandwidth: 0, availableBuffer: 100)
        #expect(cc.cwnd == 21)  // 16 + 5
    }

    @Test("cwnd grows rapidly in slow start")
    func slowStartRapid() {
        var cc = FileCC()
        // 10 ACKs of 10 packets each
        for _ in 0..<10 {
            cc.onACK(acknowledgedPackets: 10, rtt: 50_000, bandwidth: 0, availableBuffer: 1000)
        }
        #expect(cc.cwnd == 116)  // 16 + 10*10
    }

    @Test("cwnd does not exceed maximumCWND")
    func maxCWND() {
        var cc = FileCC(configuration: .init(maximumCWND: 50))
        for _ in 0..<10 {
            cc.onACK(acknowledgedPackets: 10, rtt: 50_000, bandwidth: 0, availableBuffer: 1000)
        }
        #expect(cc.cwnd == 50)
    }

    @Test("Custom initialCWND applied")
    func customInitialCWND() {
        let cc = FileCC(configuration: .init(initialCWND: 32))
        #expect(cc.cwnd == 32)
    }

    // MARK: - Slow start exit

    @Test("First onNAK transitions to congestionAvoidance")
    func slowStartExit() {
        var cc = FileCC()
        cc.onNAK(lossCount: 1)
        #expect(cc.phase == .congestionAvoidance)
    }

    @Test("cwnd decreased by 1/8 on first loss")
    func slowStartLossDecrease() {
        var cc = FileCC()
        // cwnd = 16 → 16 * 7/8 = 14
        cc.onNAK(lossCount: 1)
        #expect(cc.cwnd == 14)
    }

    @Test("Subsequent onNAK stays in congestionAvoidance")
    func subsequentNAK() {
        var cc = FileCC()
        cc.onNAK(lossCount: 1)
        #expect(cc.phase == .congestionAvoidance)
        cc.onNAK(lossCount: 1)
        #expect(cc.phase == .congestionAvoidance)
    }

    // MARK: - Congestion avoidance

    @Test("cwnd = 100, single ACK does not increase cwnd")
    func congAvoidSingleACK() {
        var cc = FileCC(configuration: .init(initialCWND: 100))
        cc.onNAK(lossCount: 1)  // Enter congestion avoidance: 100*7/8 = 87
        let afterNAK = cc.cwnd
        cc.onACK(acknowledgedPackets: 1, rtt: 50_000, bandwidth: 0, availableBuffer: 1000)
        #expect(cc.cwnd == afterNAK)  // Not enough to increment
    }

    @Test("After cwnd single-packet ACKs, cwnd increases by 1")
    func congAvoidAccumulatorIncrements() {
        var cc = FileCC(configuration: .init(initialCWND: 100))
        cc.onNAK(lossCount: 1)  // cwnd = 87
        let afterNAK = cc.cwnd  // 87
        for _ in 0..<afterNAK {
            cc.onACK(acknowledgedPackets: 1, rtt: 50_000, bandwidth: 0, availableBuffer: 1000)
        }
        #expect(cc.cwnd == afterNAK + 1)
    }

    @Test("Batch ACK with acknowledgedPackets = cwnd increments cwnd by 1")
    func congAvoidBatchACK() {
        var cc = FileCC(configuration: .init(initialCWND: 100))
        cc.onNAK(lossCount: 1)  // cwnd = 87
        let afterNAK = cc.cwnd
        cc.onACK(acknowledgedPackets: afterNAK, rtt: 50_000, bandwidth: 0, availableBuffer: 1000)
        #expect(cc.cwnd == afterNAK + 1)
    }

    // MARK: - Multiplicative decrease

    @Test("onNAK: cwnd = cwnd * 7/8")
    func nakDecrease() {
        var cc = FileCC(configuration: .init(initialCWND: 100))
        cc.onNAK(lossCount: 1)  // 100 * 7 / 8 = 87
        #expect(cc.cwnd == 87)
    }

    @Test("cwnd never goes below minimumCWND")
    func minimumCWNDEnforced() {
        var cc = FileCC(configuration: .init(initialCWND: 3, minimumCWND: 2))
        cc.onNAK(lossCount: 1)  // 3 * 7 / 8 = 2 (integer division)
        #expect(cc.cwnd >= 2)
        cc.onNAK(lossCount: 1)  // 2 * 7 / 8 = 1 → clamped to 2
        #expect(cc.cwnd == 2)
    }

    @Test("Custom minimumCWND enforced")
    func customMinimumCWND() {
        var cc = FileCC(configuration: .init(initialCWND: 10, minimumCWND: 5))
        // Repeated NAKs
        for _ in 0..<20 {
            cc.onNAK(lossCount: 1)
        }
        #expect(cc.cwnd == 5)
    }

    @Test("onTimeout: same decrease as onNAK")
    func timeoutDecrease() {
        var cc1 = FileCC(configuration: .init(initialCWND: 100))
        var cc2 = FileCC(configuration: .init(initialCWND: 100))
        cc1.onNAK(lossCount: 1)
        cc2.onTimeout()
        #expect(cc1.cwnd == cc2.cwnd)
        #expect(cc2.phase == .congestionAvoidance)
    }

    @Test("Custom decreaseNumerator: 6 means decrease by 1/4")
    func customDecreaseNumerator() {
        var cc = FileCC(configuration: .init(initialCWND: 100, decreaseNumerator: 6))
        cc.onNAK(lossCount: 1)  // 100 * 6 / 8 = 75
        #expect(cc.cwnd == 75)
    }

    // MARK: - Sending window

    @Test("sendingWindow returns min(cwnd, flow, peer)")
    func sendingWindowMin() {
        let cc = FileCC(configuration: .init(initialCWND: 50))
        #expect(cc.sendingWindow(flowWindowSize: 100, peerAvailableBuffer: 200) == 50)
    }

    @Test("flow < cwnd < peer → returns flow")
    func sendingWindowFlowSmallest() {
        let cc = FileCC(configuration: .init(initialCWND: 50))
        #expect(cc.sendingWindow(flowWindowSize: 30, peerAvailableBuffer: 200) == 30)
    }

    @Test("peer < cwnd < flow → returns peer")
    func sendingWindowPeerSmallest() {
        let cc = FileCC(configuration: .init(initialCWND: 50))
        #expect(cc.sendingWindow(flowWindowSize: 200, peerAvailableBuffer: 20) == 20)
    }

    // MARK: - No pacing

    @Test("sendingPeriod returns 0")
    func noPacing() {
        let cc = FileCC()
        #expect(cc.sendingPeriod() == 0)
    }

    @Test("congestionWindow returns cwnd")
    func congWindowReturnsCwnd() {
        let cc = FileCC(configuration: .init(initialCWND: 32))
        #expect(cc.congestionWindow() == 32)
    }

    // MARK: - Stats

    @Test("lossEventCount increments on each NAK")
    func lossEventCount() {
        var cc = FileCC()
        cc.onNAK(lossCount: 1)
        #expect(cc.lossEventCount == 1)
        cc.onNAK(lossCount: 5)
        #expect(cc.lossEventCount == 2)
    }

    @Test("lossEventCount increments on timeout")
    func lossEventCountTimeout() {
        var cc = FileCC()
        cc.onTimeout()
        #expect(cc.lossEventCount == 1)
    }

    // MARK: - Phase description

    @Test("Phase has correct descriptions")
    func phaseDescriptions() {
        #expect(FileCC.Phase.slowStart.description == "slowStart")
        #expect(FileCC.Phase.congestionAvoidance.description == "congestionAvoidance")
    }
}
