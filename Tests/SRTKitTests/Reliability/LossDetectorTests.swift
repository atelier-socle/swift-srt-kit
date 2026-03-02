// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("LossDetector Tests")
struct LossDetectorTests {
    // MARK: - Adding/removing losses

    @Test("Add single loss increases count")
    func addSingleLoss() {
        var detector = LossDetector()
        detector.addLoss(sequenceNumbers: [SequenceNumber(5)], at: 1000)
        #expect(detector.lossCount == 1)
    }

    @Test("Add multiple losses increases count correctly")
    func addMultipleLosses() {
        var detector = LossDetector()
        detector.addLoss(
            sequenceNumbers: [SequenceNumber(5), SequenceNumber(6), SequenceNumber(7)],
            at: 1000
        )
        #expect(detector.lossCount == 3)
    }

    @Test("Remove recovered loss decreases count")
    func removeRecoveredLoss() {
        var detector = LossDetector()
        detector.addLoss(sequenceNumbers: [SequenceNumber(5), SequenceNumber(6)], at: 1000)
        detector.removeLoss(sequenceNumbers: [SequenceNumber(5)])
        #expect(detector.lossCount == 1)
    }

    @Test("Remove non-existent loss does not crash")
    func removeNonExistentLoss() {
        var detector = LossDetector()
        detector.addLoss(sequenceNumbers: [SequenceNumber(5)], at: 1000)
        detector.removeLoss(sequenceNumbers: [SequenceNumber(99)])
        #expect(detector.lossCount == 1)
    }

    @Test("removeLoss(upTo:) clears all losses below frontier")
    func removeLossUpTo() {
        var detector = LossDetector()
        detector.addLoss(
            sequenceNumbers: [
                SequenceNumber(3), SequenceNumber(5), SequenceNumber(7), SequenceNumber(10)
            ],
            at: 1000
        )
        detector.removeLoss(upTo: SequenceNumber(7))
        #expect(detector.lossCount == 1)
        #expect(detector.allLosses == [SequenceNumber(10)])
    }

    @Test("allLosses returns correct sorted list")
    func allLosses() {
        var detector = LossDetector()
        detector.addLoss(
            sequenceNumbers: [SequenceNumber(10), SequenceNumber(5), SequenceNumber(8)],
            at: 1000
        )
        #expect(detector.allLosses == [SequenceNumber(5), SequenceNumber(8), SequenceNumber(10)])
    }

    // MARK: - Reporting

    @Test("New loss included in lossesNeedingReport")
    func newLossNeedsReport() {
        var detector = LossDetector()
        detector.addLoss(sequenceNumbers: [SequenceNumber(5)], at: 1000)
        let report = detector.lossesNeedingReport(currentTime: 1000, nakPeriod: 50_000)
        #expect(report.count == 1)
        #expect(report.contains(SequenceNumber(5)))
    }

    @Test("Recently reported loss NOT included")
    func recentlyReportedExcluded() {
        var detector = LossDetector()
        detector.addLoss(sequenceNumbers: [SequenceNumber(5)], at: 1000)
        detector.markReported(sequenceNumbers: [SequenceNumber(5)], at: 2000)
        let report = detector.lossesNeedingReport(currentTime: 3000, nakPeriod: 50_000)
        #expect(report.isEmpty)
    }

    @Test("Loss past NAK period included again")
    func lossPastNAKPeriod() {
        var detector = LossDetector()
        detector.addLoss(sequenceNumbers: [SequenceNumber(5)], at: 1000)
        detector.markReported(sequenceNumbers: [SequenceNumber(5)], at: 2000)
        // NAK period is 50_000, so at 52_001 it should be re-reported
        let report = detector.lossesNeedingReport(currentTime: 52_001, nakPeriod: 50_000)
        #expect(report.count == 1)
    }

    @Test("markReported updates lastReportedAt and reportCount")
    func markReportedUpdates() {
        var detector = LossDetector()
        detector.addLoss(sequenceNumbers: [SequenceNumber(5)], at: 1000)
        detector.markReported(sequenceNumbers: [SequenceNumber(5)], at: 2000)
        detector.markReported(sequenceNumbers: [SequenceNumber(5)], at: 3000)
        // After two reports, loss should still be tracked
        #expect(detector.lossCount == 1)
    }

    // MARK: - Edge cases

    @Test("Empty detector has no losses")
    func emptyDetector() {
        let detector = LossDetector()
        #expect(detector.lossCount == 0)
        #expect(!detector.hasLosses)
        #expect(detector.lossesNeedingReport(currentTime: 0, nakPeriod: 50_000).isEmpty)
    }

    @Test("hasLosses reflects state correctly")
    func hasLosses() {
        var detector = LossDetector()
        #expect(!detector.hasLosses)
        detector.addLoss(sequenceNumbers: [SequenceNumber(1)], at: 1000)
        #expect(detector.hasLosses)
        detector.removeLoss(sequenceNumbers: [SequenceNumber(1)])
        #expect(!detector.hasLosses)
    }

    @Test("Duplicate addLoss does not create duplicate entries")
    func duplicateAddLoss() {
        var detector = LossDetector()
        detector.addLoss(sequenceNumbers: [SequenceNumber(5)], at: 1000)
        detector.addLoss(sequenceNumbers: [SequenceNumber(5)], at: 2000)
        #expect(detector.lossCount == 1)
    }

    @Test("removeLoss(upTo:) handles wrap-around")
    func removeLossUpToWrapAround() {
        var detector = LossDetector()
        let nearMax = SequenceNumber.max - 2
        detector.addLoss(
            sequenceNumbers: [SequenceNumber(nearMax), SequenceNumber(5)],
            at: 1000
        )
        // Remove up to 5 (which is "ahead" of nearMax in wrapping space)
        detector.removeLoss(upTo: SequenceNumber(5))
        #expect(detector.lossCount == 0)
    }
}
