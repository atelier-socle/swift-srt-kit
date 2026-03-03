// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("NetworkSnapshot Tests")
struct NetworkSnapshotTests {
    @Test("Default init has all zeros/defaults")
    func defaultInit() {
        let snapshot = NetworkSnapshot()
        #expect(snapshot.rttMicroseconds == 0)
        #expect(snapshot.rttVarianceMicroseconds == 0)
        #expect(snapshot.estimatedBandwidthBps == 0)
        #expect(snapshot.sendRateBps == 0)
        #expect(snapshot.maxBandwidthBps == 0)
        #expect(snapshot.lossRate == 0)
        #expect(snapshot.packetsInFlight == 0)
        #expect(snapshot.sendBufferUtilization == 0)
        #expect(snapshot.uptimeMicroseconds == 0)
    }

    @Test("flowWindowAvailable defaults to 25600")
    func flowWindowDefault() {
        let snapshot = NetworkSnapshot()
        #expect(snapshot.flowWindowAvailable == 25600)
    }

    @Test("Custom init sets all fields")
    func customInit() {
        let snapshot = NetworkSnapshot(
            rttMicroseconds: 20_000,
            rttVarianceMicroseconds: 3_000,
            estimatedBandwidthBps: 5_000_000,
            sendRateBps: 4_000_000,
            maxBandwidthBps: 10_000_000,
            lossRate: 0.01,
            packetsInFlight: 50,
            sendBufferUtilization: 0.3,
            flowWindowAvailable: 12800,
            uptimeMicroseconds: 60_000_000)
        #expect(snapshot.rttMicroseconds == 20_000)
        #expect(snapshot.estimatedBandwidthBps == 5_000_000)
        #expect(snapshot.lossRate == 0.01)
        #expect(snapshot.packetsInFlight == 50)
        #expect(snapshot.flowWindowAvailable == 12800)
    }

    @Test("Equatable works")
    func equatable() {
        let a = NetworkSnapshot(rttMicroseconds: 100)
        let b = NetworkSnapshot(rttMicroseconds: 100)
        let c = NetworkSnapshot(rttMicroseconds: 200)
        #expect(a == b)
        #expect(a != c)
    }
}
