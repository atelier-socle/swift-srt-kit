// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTStatistics Tests")
struct SRTStatisticsTests {
    // MARK: - Initialization

    @Test("Default init creates all-zero statistics")
    func defaultInitAllZeros() {
        let stats = SRTStatistics()
        #expect(stats.packetsSent == 0)
        #expect(stats.packetsReceived == 0)
        #expect(stats.packetsSentLost == 0)
        #expect(stats.packetsReceivedLost == 0)
        #expect(stats.packetsRetransmitted == 0)
        #expect(stats.bytesSent == 0)
        #expect(stats.bytesReceived == 0)
        #expect(stats.rttMicroseconds == 0)
        #expect(stats.bandwidthBitsPerSecond == 0)
        #expect(stats.keyRotations == 0)
    }

    @Test("Custom init sets all fields correctly")
    func customInit() {
        let stats = SRTStatistics(
            packetsSent: 100,
            packetsReceived: 95,
            packetsSentLost: 3,
            rttMicroseconds: 45000,
            sendBufferPackets: 50,
            sendBufferCapacity: 4096
        )
        #expect(stats.packetsSent == 100)
        #expect(stats.packetsReceived == 95)
        #expect(stats.packetsSentLost == 3)
        #expect(stats.rttMicroseconds == 45000)
        #expect(stats.sendBufferPackets == 50)
        #expect(stats.sendBufferCapacity == 4096)
    }

    @Test("Default buffer capacities")
    func defaultBufferCapacities() {
        let stats = SRTStatistics()
        #expect(stats.sendBufferCapacity == 8192)
        #expect(stats.receiveBufferCapacity == 8192)
        #expect(stats.flowWindowAvailable == 25600)
    }

    @Test("Equatable: same values are equal")
    func equatableSameValues() {
        let a = SRTStatistics(packetsSent: 10, packetsReceived: 20)
        let b = SRTStatistics(packetsSent: 10, packetsReceived: 20)
        #expect(a == b)
    }

    @Test("Equatable: different packetsSent are not equal")
    func equatableDifferentValues() {
        let a = SRTStatistics(packetsSent: 10)
        let b = SRTStatistics(packetsSent: 20)
        #expect(a != b)
    }

    // MARK: - Computed properties

    @Test("lossRate with 0 packets returns 0")
    func lossRateZeroPackets() {
        let stats = SRTStatistics()
        #expect(stats.lossRate == 0)
    }

    @Test("lossRate with 100 sent, 5 sent-lost returns 0.05")
    func lossRateWithLoss() {
        let stats = SRTStatistics(
            packetsSent: 100,
            packetsSentLost: 5
        )
        #expect(stats.lossRate == 0.05)
    }

    @Test("lossRate with only receive losses")
    func lossRateReceiveLosses() {
        let stats = SRTStatistics(
            packetsReceived: 200,
            packetsReceivedLost: 10
        )
        #expect(stats.lossRate == 0.05)
    }

    @Test("sendBufferUtilization: 0/8192 returns 0")
    func sendBufferUtilizationZero() {
        let stats = SRTStatistics(sendBufferPackets: 0, sendBufferCapacity: 8192)
        #expect(stats.sendBufferUtilization == 0)
    }

    @Test("sendBufferUtilization: 4096/8192 returns 0.5")
    func sendBufferUtilizationHalf() {
        let stats = SRTStatistics(sendBufferPackets: 4096, sendBufferCapacity: 8192)
        #expect(stats.sendBufferUtilization == 0.5)
    }

    @Test("sendBufferUtilization: 8192/8192 returns 1.0")
    func sendBufferUtilizationFull() {
        let stats = SRTStatistics(sendBufferPackets: 8192, sendBufferCapacity: 8192)
        #expect(stats.sendBufferUtilization == 1.0)
    }

    @Test("sendBufferUtilization: capacity 0 returns 0")
    func sendBufferUtilizationZeroCapacity() {
        let stats = SRTStatistics(sendBufferPackets: 0, sendBufferCapacity: 0)
        #expect(stats.sendBufferUtilization == 0)
    }

    @Test("receiveBufferUtilization: 1000/8192")
    func receiveBufferUtilization() {
        let stats = SRTStatistics(receiveBufferPackets: 1000, receiveBufferCapacity: 8192)
        let expected = Double(1000) / Double(8192)
        #expect(abs(stats.receiveBufferUtilization - expected) < 0.0001)
    }

    @Test("receiveBufferUtilization: capacity 0 returns 0")
    func receiveBufferUtilizationZeroCapacity() {
        let stats = SRTStatistics(receiveBufferPackets: 0, receiveBufferCapacity: 0)
        #expect(stats.receiveBufferUtilization == 0)
    }

    @Test("lossRate with both send and receive losses")
    func lossRateCombined() {
        let stats = SRTStatistics(
            packetsSent: 100,
            packetsReceived: 100,
            packetsSentLost: 5,
            packetsReceivedLost: 5
        )
        #expect(stats.lossRate == 0.05)
    }
}
