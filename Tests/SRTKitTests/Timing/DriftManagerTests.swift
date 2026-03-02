// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("DriftManager Tests")
struct DriftManagerTests {
    // MARK: - Sample collection

    @Test("Add single sample increases sampleCount")
    func addSingleSample() {
        var mgr = DriftManager(configuration: .init(windowSize: 100, minSamplesForCorrection: 20))
        mgr.addSample(
            senderTimestamp: 10_000, receiveTime: 1_010_000,
            previousSenderTimestamp: 0, previousReceiveTime: 1_000_000
        )
        #expect(mgr.sampleCount == 1)
    }

    @Test("Add up to windowSize increases sampleCount")
    func addUpToWindowSize() {
        var mgr = DriftManager(configuration: .init(windowSize: 10, minSamplesForCorrection: 5))
        for i: UInt32 in 1...10 {
            mgr.addSample(
                senderTimestamp: i * 10_000, receiveTime: UInt64(i) * 10_000 + 1_000_000,
                previousSenderTimestamp: (i - 1) * 10_000,
                previousReceiveTime: UInt64(i - 1) * 10_000 + 1_000_000
            )
        }
        #expect(mgr.sampleCount == 10)
    }

    @Test("Beyond windowSize replaces oldest samples")
    func beyondWindowSize() {
        var mgr = DriftManager(configuration: .init(windowSize: 5, minSamplesForCorrection: 2))
        for i: UInt32 in 1...10 {
            mgr.addSample(
                senderTimestamp: i * 10_000, receiveTime: UInt64(i) * 10_000 + 1_000_000,
                previousSenderTimestamp: (i - 1) * 10_000,
                previousReceiveTime: UInt64(i - 1) * 10_000 + 1_000_000
            )
        }
        #expect(mgr.sampleCount == 5)
    }

    @Test("hasEnoughSamples false until minSamplesForCorrection")
    func hasEnoughSamples() {
        var mgr = DriftManager(configuration: .init(windowSize: 100, minSamplesForCorrection: 3))
        #expect(!mgr.hasEnoughSamples)
        for i: UInt32 in 1...2 {
            mgr.addSample(
                senderTimestamp: i * 10_000, receiveTime: UInt64(i) * 10_000 + 1_000_000,
                previousSenderTimestamp: (i - 1) * 10_000,
                previousReceiveTime: UInt64(i - 1) * 10_000 + 1_000_000
            )
        }
        #expect(!mgr.hasEnoughSamples)
        mgr.addSample(
            senderTimestamp: 30_000, receiveTime: 1_030_000,
            previousSenderTimestamp: 20_000, previousReceiveTime: 1_020_000
        )
        #expect(mgr.hasEnoughSamples)
    }

    // MARK: - No drift (synchronized clocks)

    @Test("Equal gaps produce zero average drift")
    func zeroDrift() {
        var mgr = DriftManager(configuration: .init(windowSize: 100, minSamplesForCorrection: 5))
        for i: UInt32 in 1...10 {
            // Sender gap = 10_000, receiver gap = 10_000 → drift = 0
            mgr.addSample(
                senderTimestamp: i * 10_000, receiveTime: UInt64(i) * 10_000 + 1_000_000,
                previousSenderTimestamp: (i - 1) * 10_000,
                previousReceiveTime: UInt64(i - 1) * 10_000 + 1_000_000
            )
        }
        #expect(mgr.averageDrift == 0)
        #expect(mgr.calculateCorrection() == 0)
    }

    // MARK: - Positive drift (receiver clock faster)

    @Test("Receiver faster produces positive drift")
    func positiveDrift() {
        var mgr = DriftManager(
            configuration: .init(
                windowSize: 100, maxCorrectionPerPeriod: 100_000, minSamplesForCorrection: 5
            ))
        for i: UInt32 in 1...10 {
            // Sender gap = 10_000, receiver gap = 10_100 → drift = +100 per sample
            mgr.addSample(
                senderTimestamp: i * 10_000,
                receiveTime: UInt64(i) * 10_100 + 1_000_000,
                previousSenderTimestamp: (i - 1) * 10_000,
                previousReceiveTime: UInt64(i - 1) * 10_100 + 1_000_000
            )
        }
        #expect(mgr.averageDrift == 100)
        #expect(mgr.calculateCorrection() == 100)
    }

    @Test("applyCorrection adds to totalCorrection")
    func applyCorrection() {
        var mgr = DriftManager(
            configuration: .init(
                windowSize: 100, maxCorrectionPerPeriod: 100_000, minSamplesForCorrection: 5
            ))
        for i: UInt32 in 1...10 {
            mgr.addSample(
                senderTimestamp: i * 10_000,
                receiveTime: UInt64(i) * 10_100 + 1_000_000,
                previousSenderTimestamp: (i - 1) * 10_000,
                previousReceiveTime: UInt64(i - 1) * 10_100 + 1_000_000
            )
        }
        let correction = mgr.applyCorrection()
        #expect(correction == 100)
        #expect(mgr.totalCorrection == 100)
        #expect(mgr.sampleCount == 0)
    }

    // MARK: - Negative drift (receiver clock slower)

    @Test("Receiver slower produces negative drift")
    func negativeDrift() {
        var mgr = DriftManager(
            configuration: .init(
                windowSize: 100, maxCorrectionPerPeriod: 100_000, minSamplesForCorrection: 5
            ))
        for i: UInt32 in 1...10 {
            // Sender gap = 10_000, receiver gap = 9_900 → drift = -100
            mgr.addSample(
                senderTimestamp: i * 10_000,
                receiveTime: UInt64(i) * 9_900 + 1_000_000,
                previousSenderTimestamp: (i - 1) * 10_000,
                previousReceiveTime: UInt64(i - 1) * 9_900 + 1_000_000
            )
        }
        #expect(mgr.averageDrift == -100)
        #expect(mgr.calculateCorrection() == -100)
    }

    // MARK: - Clamping

    @Test("Large drift capped at maxCorrectionPerPeriod")
    func clampedDrift() {
        var mgr = DriftManager(
            configuration: .init(
                windowSize: 100, maxCorrectionPerPeriod: 5_000, minSamplesForCorrection: 5
            ))
        for i: UInt32 in 1...10 {
            // Sender gap = 10_000, receiver gap = 20_000 → drift = +10_000
            mgr.addSample(
                senderTimestamp: i * 10_000,
                receiveTime: UInt64(i) * 20_000 + 1_000_000,
                previousSenderTimestamp: (i - 1) * 10_000,
                previousReceiveTime: UInt64(i - 1) * 20_000 + 1_000_000
            )
        }
        #expect(mgr.averageDrift == 10_000)
        #expect(mgr.calculateCorrection() == 5_000)
    }

    @Test("Multiple periods accumulate corrections")
    func multiplePeriods() {
        var mgr = DriftManager(
            configuration: .init(
                windowSize: 100, maxCorrectionPerPeriod: 5_000, minSamplesForCorrection: 5
            ))
        // Period 1
        for i: UInt32 in 1...10 {
            mgr.addSample(
                senderTimestamp: i * 10_000,
                receiveTime: UInt64(i) * 20_000 + 1_000_000,
                previousSenderTimestamp: (i - 1) * 10_000,
                previousReceiveTime: UInt64(i - 1) * 20_000 + 1_000_000
            )
        }
        mgr.applyCorrection()
        #expect(mgr.totalCorrection == 5_000)

        // Period 2
        for i: UInt32 in 11...20 {
            mgr.addSample(
                senderTimestamp: i * 10_000,
                receiveTime: UInt64(i) * 20_000 + 1_000_000,
                previousSenderTimestamp: (i - 1) * 10_000,
                previousReceiveTime: UInt64(i - 1) * 20_000 + 1_000_000
            )
        }
        mgr.applyCorrection()
        #expect(mgr.totalCorrection == 10_000)
    }

    // MARK: - Reset

    @Test("Reset clears everything")
    func reset() {
        var mgr = DriftManager(
            configuration: .init(
                windowSize: 100, maxCorrectionPerPeriod: 100_000, minSamplesForCorrection: 5
            ))
        for i: UInt32 in 1...10 {
            mgr.addSample(
                senderTimestamp: i * 10_000,
                receiveTime: UInt64(i) * 10_100 + 1_000_000,
                previousSenderTimestamp: (i - 1) * 10_000,
                previousReceiveTime: UInt64(i - 1) * 10_100 + 1_000_000
            )
        }
        mgr.applyCorrection()
        mgr.reset()
        #expect(mgr.totalCorrection == 0)
        #expect(mgr.sampleCount == 0)
        #expect(mgr.averageDrift == 0)
    }

    // MARK: - Timestamp wrap-around

    @Test("Sender timestamps wrapping does not produce false drift")
    func timestampWrapAround() {
        var mgr = DriftManager(
            configuration: .init(
                windowSize: 100, maxCorrectionPerPeriod: 100_000, minSamplesForCorrection: 5
            ))
        // Simulate wrap: sender goes from near-max to near-zero
        let nearMax = UInt32.max - 5_000
        for i: UInt32 in 1...10 {
            let prevSender = nearMax &+ (i &- 1) &* 10_000
            let currSender = nearMax &+ i &* 10_000
            // Receiver clock matches perfectly
            let prevReceive = UInt64(i - 1) * 10_000 + 1_000_000
            let currReceive = UInt64(i) * 10_000 + 1_000_000
            mgr.addSample(
                senderTimestamp: currSender, receiveTime: currReceive,
                previousSenderTimestamp: prevSender, previousReceiveTime: prevReceive
            )
        }
        #expect(mgr.averageDrift == 0)
    }

    // MARK: - Jitter

    @Test("Random jitter averages near zero")
    func jitterAveragesNearZero() {
        var mgr = DriftManager(
            configuration: .init(
                windowSize: 100, maxCorrectionPerPeriod: 100_000, minSamplesForCorrection: 5
            ))
        // Alternating +500 / -500 jitter
        for i: UInt32 in 1...20 {
            let jitter: UInt64 = i % 2 == 0 ? 500 : 0
            let antiJitter: UInt64 = i % 2 == 0 ? 0 : 500
            mgr.addSample(
                senderTimestamp: i * 10_000,
                receiveTime: UInt64(i) * 10_000 + 1_000_000 + jitter - antiJitter,
                previousSenderTimestamp: (i - 1) * 10_000,
                previousReceiveTime: UInt64(i - 1) * 10_000 + 1_000_000
                    + (i % 2 == 0 ? antiJitter : 0) - (i % 2 == 0 ? 0 : antiJitter)
            )
        }
        // Average should be near zero (within jitter magnitude)
        let avg = mgr.averageDrift
        #expect(avg >= -500 && avg <= 500)
    }

    @Test("Not enough samples returns zero correction")
    func notEnoughSamples() {
        var mgr = DriftManager(configuration: .init(windowSize: 100, minSamplesForCorrection: 20))
        for i: UInt32 in 1...5 {
            mgr.addSample(
                senderTimestamp: i * 10_000,
                receiveTime: UInt64(i) * 20_000 + 1_000_000,
                previousSenderTimestamp: (i - 1) * 10_000,
                previousReceiveTime: UInt64(i - 1) * 20_000 + 1_000_000
            )
        }
        #expect(!mgr.hasEnoughSamples)
        #expect(mgr.calculateCorrection() == 0)
    }
}
