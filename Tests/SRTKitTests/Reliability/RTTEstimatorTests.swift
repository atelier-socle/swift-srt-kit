// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("RTTEstimator Tests")
struct RTTEstimatorTests {
    @Test("Default initialRTT is 100_000")
    func defaultInitialRTT() {
        let estimator = RTTEstimator()
        #expect(estimator.smoothedRTT == 100_000)
    }

    @Test("Custom initialRTT sets smoothedRTT")
    func customInitialRTT() {
        let estimator = RTTEstimator(initialRTT: 50_000)
        #expect(estimator.smoothedRTT == 50_000)
    }

    @Test("Initial variance is half of initialRTT")
    func initialVariance() {
        let estimator = RTTEstimator(initialRTT: 100_000)
        #expect(estimator.variance == 50_000)
    }

    @Test("First update sets smoothedRTT directly")
    func firstUpdate() {
        var estimator = RTTEstimator(initialRTT: 100_000)
        estimator.update(rtt: 80_000)
        #expect(estimator.smoothedRTT == 80_000)
        #expect(estimator.sampleCount == 1)
    }

    @Test("First update sets variance to half of sample")
    func firstUpdateVariance() {
        var estimator = RTTEstimator(initialRTT: 100_000)
        estimator.update(rtt: 80_000)
        #expect(estimator.variance == 40_000)
    }

    @Test("Subsequent updates use EWMA formula")
    func ewmaUpdate() {
        var estimator = RTTEstimator(initialRTT: 100_000)
        estimator.update(rtt: 80_000)  // smoothed = 80_000
        estimator.update(rtt: 80_000)  // smoothed = (7*80000+80000)/8 = 80_000
        #expect(estimator.smoothedRTT == 80_000)
    }

    @Test("Smoothed RTT converges toward stable value")
    func convergence() {
        var estimator = RTTEstimator(initialRTT: 100_000)
        // Feed consistent 50ms RTT
        for _ in 0..<20 {
            estimator.update(rtt: 50_000)
        }
        // Should converge close to 50_000
        let diff =
            estimator.smoothedRTT > 50_000
            ? estimator.smoothedRTT - 50_000
            : 50_000 - estimator.smoothedRTT
        #expect(diff < 1_000)
    }

    @Test("Variance decreases with consistent RTT")
    func varianceDecreasesConsistent() {
        var estimator = RTTEstimator(initialRTT: 100_000)
        estimator.update(rtt: 80_000)
        let v1 = estimator.variance
        for _ in 0..<10 {
            estimator.update(rtt: 80_000)
        }
        #expect(estimator.variance < v1)
    }

    @Test("Variance increases with jittery RTT")
    func varianceIncreasesJitter() {
        var estimator = RTTEstimator(initialRTT: 100_000)
        // Initialize with consistent RTT
        for _ in 0..<10 {
            estimator.update(rtt: 80_000)
        }
        let stableVariance = estimator.variance
        // Now introduce jitter
        estimator.update(rtt: 200_000)
        #expect(estimator.variance > stableVariance)
    }

    @Test("nakPeriod = 4 * smoothedRTT + variance + 10_000")
    func nakPeriod() {
        var estimator = RTTEstimator(initialRTT: 100_000)
        estimator.update(rtt: 100_000)
        // After first sample: smoothed = 100_000, variance = 50_000
        let expected = 4 * estimator.smoothedRTT + estimator.variance + 10_000
        #expect(estimator.nakPeriod == expected)
    }

    @Test("sampleCount increments on each update")
    func sampleCount() {
        var estimator = RTTEstimator()
        #expect(estimator.sampleCount == 0)
        estimator.update(rtt: 100_000)
        #expect(estimator.sampleCount == 1)
        estimator.update(rtt: 90_000)
        #expect(estimator.sampleCount == 2)
    }

    @Test("RTT of 0 handled without crash")
    func rttZero() {
        var estimator = RTTEstimator(initialRTT: 100_000)
        estimator.update(rtt: 0)
        #expect(estimator.smoothedRTT == 0)
        estimator.update(rtt: 0)
        #expect(estimator.smoothedRTT == 0)
    }

    @Test("Large RTT spike partially absorbed by smoothing")
    func largeSpike() {
        var estimator = RTTEstimator(initialRTT: 100_000)
        estimator.update(rtt: 100_000)  // smoothed = 100_000
        estimator.update(rtt: 500_000)  // smoothed = (7*100000+500000)/8 = 150_000
        #expect(estimator.smoothedRTT == 150_000)
        // Spike partially absorbed, not fully reflected
        #expect(estimator.smoothedRTT < 500_000)
        #expect(estimator.smoothedRTT > 100_000)
    }
}
