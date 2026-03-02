// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("BandwidthEstimator Tests")
struct BandwidthEstimatorTests {
    // MARK: - Probe collection

    @Test("First packet of pair: no estimate yet")
    func firstPacketNoEstimate() {
        var est = BandwidthEstimator()
        est.recordProbePacket(packetSize: 1332, receiveTime: 1_000_000, isSecondOfPair: false)
        #expect(est.estimateCount == 0)
        #expect(est.estimatedBandwidth == 0)
    }

    @Test("Second packet of pair generates estimate")
    func secondPacketEstimate() {
        var est = BandwidthEstimator()
        est.recordProbePacket(packetSize: 1332, receiveTime: 1_000_000, isSecondOfPair: false)
        est.recordProbePacket(packetSize: 1332, receiveTime: 1_001_000, isSecondOfPair: true)
        #expect(est.estimateCount == 1)
        #expect(est.estimatedBandwidth > 0)
    }

    @Test("Estimate calculation is correct")
    func estimateValue() {
        var est = BandwidthEstimator()
        est.recordProbePacket(packetSize: 1332, receiveTime: 1_000_000, isSecondOfPair: false)
        est.recordProbePacket(packetSize: 1332, receiveTime: 1_001_000, isSecondOfPair: true)
        // 1332 * 8 * 1_000_000 / 1000 = 10_656_000_000 / 1000 = 10_656_000
        #expect(est.estimatedBandwidth == 10_656_000)
    }

    @Test("Zero inter-arrival discarded")
    func zeroInterArrival() {
        var est = BandwidthEstimator()
        est.recordProbePacket(packetSize: 1332, receiveTime: 1_000_000, isSecondOfPair: false)
        est.recordProbePacket(packetSize: 1332, receiveTime: 1_000_000, isSecondOfPair: true)
        #expect(est.estimateCount == 0)
    }

    @Test("Below minimum inter-arrival discarded")
    func belowMinInterArrival() {
        var est = BandwidthEstimator(configuration: .init(minInterArrival: 100))
        est.recordProbePacket(packetSize: 1332, receiveTime: 1_000_000, isSecondOfPair: false)
        est.recordProbePacket(packetSize: 1332, receiveTime: 1_000_050, isSecondOfPair: true)
        #expect(est.estimateCount == 0)
    }

    @Test("Second without first is ignored")
    func secondWithoutFirst() {
        var est = BandwidthEstimator()
        est.recordProbePacket(packetSize: 1332, receiveTime: 1_001_000, isSecondOfPair: true)
        #expect(est.estimateCount == 0)
    }

    // MARK: - Median filter

    @Test("Single estimate returns that estimate")
    func singleEstimate() {
        var est = BandwidthEstimator()
        est.recordProbePacket(packetSize: 1332, receiveTime: 1_000_000, isSecondOfPair: false)
        est.recordProbePacket(packetSize: 1332, receiveTime: 1_001_000, isSecondOfPair: true)
        #expect(est.estimatedBandwidth == 10_656_000)
    }

    @Test("Three estimates returns median")
    func threeEstimatesMedian() {
        var est = BandwidthEstimator()
        // Estimate 1: interArrival = 1000 → 10_656_000
        est.recordProbePacket(packetSize: 1332, receiveTime: 1_000_000, isSecondOfPair: false)
        est.recordProbePacket(packetSize: 1332, receiveTime: 1_001_000, isSecondOfPair: true)
        // Estimate 2: interArrival = 500 → 21_312_000
        est.recordProbePacket(packetSize: 1332, receiveTime: 2_000_000, isSecondOfPair: false)
        est.recordProbePacket(packetSize: 1332, receiveTime: 2_000_500, isSecondOfPair: true)
        // Estimate 3: interArrival = 2000 → 5_328_000
        est.recordProbePacket(packetSize: 1332, receiveTime: 3_000_000, isSecondOfPair: false)
        est.recordProbePacket(packetSize: 1332, receiveTime: 3_002_000, isSecondOfPair: true)
        // Sorted: 5_328_000, 10_656_000, 21_312_000 → median = 10_656_000
        #expect(est.estimatedBandwidth == 10_656_000)
    }

    @Test("Window rolls over after windowSize estimates")
    func windowRollover() {
        var est = BandwidthEstimator(configuration: .init(windowSize: 3))
        for i: UInt64 in 0..<5 {
            let base = i * 10_000_000
            est.recordProbePacket(packetSize: 1332, receiveTime: base, isSecondOfPair: false)
            est.recordProbePacket(
                packetSize: 1332, receiveTime: base + 1000, isSecondOfPair: true)
        }
        #expect(est.estimateCount == 3)
    }

    // MARK: - Capacity

    @Test("estimatedCapacity calculation correct")
    func capacityCalculation() {
        var est = BandwidthEstimator()
        est.recordProbePacket(packetSize: 1332, receiveTime: 1_000_000, isSecondOfPair: false)
        est.recordProbePacket(packetSize: 1332, receiveTime: 1_001_000, isSecondOfPair: true)
        // 10_656_000 / (1332 * 8) = 10_656_000 / 10656 = 1000
        #expect(est.estimatedCapacity(avgPacketSize: 1332) == 1000)
    }

    @Test("estimatedCapacity with zero packet size returns 0")
    func capacityZeroSize() {
        let est = BandwidthEstimator()
        #expect(est.estimatedCapacity(avgPacketSize: 0) == 0)
    }

    // MARK: - State

    @Test("estimateCount tracks collected probes")
    func estimateCount() {
        var est = BandwidthEstimator()
        #expect(est.estimateCount == 0)
        est.recordProbePacket(packetSize: 1332, receiveTime: 0, isSecondOfPair: false)
        est.recordProbePacket(packetSize: 1332, receiveTime: 1000, isSecondOfPair: true)
        #expect(est.estimateCount == 1)
    }

    @Test("hasReliableEstimate after windowSize/2 probes")
    func reliable() {
        var est = BandwidthEstimator(configuration: .init(windowSize: 8))
        #expect(!est.hasReliableEstimate)
        for i: UInt64 in 0..<4 {
            let base = i * 10_000
            est.recordProbePacket(packetSize: 1332, receiveTime: base, isSecondOfPair: false)
            est.recordProbePacket(
                packetSize: 1332, receiveTime: base + 1000, isSecondOfPair: true)
        }
        #expect(est.hasReliableEstimate)
    }

    @Test("reset clears all estimates")
    func reset() {
        var est = BandwidthEstimator()
        est.recordProbePacket(packetSize: 1332, receiveTime: 0, isSecondOfPair: false)
        est.recordProbePacket(packetSize: 1332, receiveTime: 1000, isSecondOfPair: true)
        est.reset()
        #expect(est.estimateCount == 0)
        #expect(est.estimatedBandwidth == 0)
        #expect(!est.hasReliableEstimate)
    }

    // MARK: - Edge cases

    @Test("Large bandwidth does not overflow")
    func largeBandwidth() {
        var est = BandwidthEstimator()
        // 1 µs inter-arrival → very high bandwidth
        est.recordProbePacket(packetSize: 1332, receiveTime: 1_000_000, isSecondOfPair: false)
        est.recordProbePacket(packetSize: 1332, receiveTime: 1_000_001, isSecondOfPair: true)
        // 1332 * 8 * 1_000_000 / 1 = 10_656_000_000
        #expect(est.estimatedBandwidth == 10_656_000_000)
    }
}
