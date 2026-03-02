// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("TimestampHelper Tests")
struct TimestampHelperTests {
    // MARK: - difference()

    @Test("Simple positive difference")
    func differencePositive() {
        #expect(TimestampHelper.difference(200, 100) == 100)
    }

    @Test("Zero difference")
    func differenceZero() {
        #expect(TimestampHelper.difference(100, 100) == 0)
    }

    @Test("Negative difference")
    func differenceNegative() {
        #expect(TimestampHelper.difference(100, 200) == -100)
    }

    @Test("Wrap-around forward")
    func differenceWrapForward() {
        let t1 = UInt32.max - 50
        let t2: UInt32 = 50
        let diff = TimestampHelper.difference(t2, t1)
        #expect(diff == 101)
    }

    @Test("Wrap-around backward")
    func differenceWrapBackward() {
        let t1: UInt32 = 50
        let t2 = UInt32.max - 50
        let diff = TimestampHelper.difference(t2, t1)
        #expect(diff == -101)
    }

    @Test("Half-way point is negative")
    func differenceHalfway() {
        let t1: UInt32 = 0
        let t2 = UInt32(Int32.max) + 1  // 2^31
        let diff = TimestampHelper.difference(t2, t1)
        // Past the halfway point: interpreted as negative
        #expect(diff < 0)
    }

    @Test("Large values near max")
    func differenceLargeValues() {
        let t1 = UInt32.max - 1000
        let t2 = UInt32.max - 500
        let diff = TimestampHelper.difference(t2, t1)
        #expect(diff == 500)
    }

    // MARK: - isAfter()

    @Test("Simple forward case returns true")
    func isAfterForward() {
        #expect(TimestampHelper.isAfter(200, 100))
    }

    @Test("Simple backward case returns false")
    func isAfterBackward() {
        #expect(!TimestampHelper.isAfter(100, 200))
    }

    @Test("Equal timestamps returns false")
    func isAfterEqual() {
        #expect(!TimestampHelper.isAfter(100, 100))
    }

    @Test("Wrap-around forward returns true")
    func isAfterWrapForward() {
        #expect(TimestampHelper.isAfter(10, UInt32.max - 10))
    }

    @Test("Wrap-around backward returns false")
    func isAfterWrapBackward() {
        #expect(!TimestampHelper.isAfter(UInt32.max - 10, 10))
    }

    // MARK: - add()

    @Test("Add positive offset")
    func addPositive() {
        #expect(TimestampHelper.add(100, offset: 50) == 150)
    }

    @Test("Add wraps past max")
    func addWraps() {
        let result = TimestampHelper.add(UInt32.max - 10, offset: 20)
        #expect(result == 9)
    }

    @Test("Add negative offset")
    func addNegative() {
        #expect(TimestampHelper.add(100, offset: -50) == 50)
    }

    @Test("Negative offset wrapping")
    func addNegativeWraps() {
        let result = TimestampHelper.add(10, offset: -20)
        #expect(result == UInt32.max - 9)
    }

    // MARK: - Conversions

    @Test("msToUs converts correctly")
    func msToUs() {
        #expect(TimestampHelper.msToUs(120) == 120_000)
    }

    @Test("usToMs converts correctly")
    func usToMs() {
        #expect(TimestampHelper.usToMs(120_000) == 120)
    }

    @Test("usToMs truncates")
    func usToMsTruncates() {
        #expect(TimestampHelper.usToMs(120_500) == 120)
    }

    @Test("msToUs zero")
    func msToUsZero() {
        #expect(TimestampHelper.msToUs(0) == 0)
    }
}
