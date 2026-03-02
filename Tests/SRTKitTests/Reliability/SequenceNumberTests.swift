// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SequenceNumber Tests")
struct SequenceNumberTests {
    // MARK: - Creation

    @Test("Create with zero value")
    func createZero() {
        let sn = SequenceNumber(0)
        #expect(sn.value == 0)
    }

    @Test("Create with max value")
    func createMax() {
        let sn = SequenceNumber(SequenceNumber.max)
        #expect(sn.value == 0x7FFF_FFFF)
    }

    @Test("Create masks to 31 bits")
    func createMasks() {
        let sn = SequenceNumber(0xFFFF_FFFF)
        #expect(sn.value == 0x7FFF_FFFF)
    }

    @Test("Create with arbitrary value")
    func createArbitrary() {
        let sn = SequenceNumber(42)
        #expect(sn.value == 42)
    }

    @Test("Create with high bit set masks correctly")
    func createHighBitMasked() {
        let sn = SequenceNumber(0x8000_0000)
        #expect(sn.value == 0)
    }

    // MARK: - Addition

    @Test("Add positive offset")
    func addPositive() {
        let sn = SequenceNumber(10)
        let result = sn + 5
        #expect(result.value == 15)
    }

    @Test("Add negative offset")
    func addNegative() {
        let sn = SequenceNumber(10)
        let result = sn + (-3)
        #expect(result.value == 7)
    }

    @Test("Add wraps forward past max")
    func addWrapsForward() {
        let sn = SequenceNumber(SequenceNumber.max)
        let result = sn + 1
        #expect(result.value == 0)
    }

    @Test("Add wraps forward by more than 1")
    func addWrapsForwardMultiple() {
        let sn = SequenceNumber(SequenceNumber.max - 2)
        let result = sn + 5
        #expect(result.value == 2)
    }

    @Test("Add zero returns same value")
    func addZero() {
        let sn = SequenceNumber(100)
        let result = sn + 0
        #expect(result.value == 100)
    }

    // MARK: - Subtraction

    @Test("Subtract positive offset")
    func subtractPositive() {
        let sn = SequenceNumber(10)
        let result = sn - 3
        #expect(result.value == 7)
    }

    @Test("Subtract wraps backward past zero")
    func subtractWrapsBackward() {
        let sn = SequenceNumber(0)
        let result = sn - 1
        #expect(result.value == SequenceNumber.max)
    }

    @Test("Subtract wraps backward by more than 1")
    func subtractWrapsBackwardMultiple() {
        let sn = SequenceNumber(2)
        let result = sn - 5
        #expect(result.value == SequenceNumber.max - 2)
    }

    // MARK: - Distance

    @Test("Distance forward simple")
    func distanceForwardSimple() {
        let a = SequenceNumber(10)
        let b = SequenceNumber(20)
        #expect(SequenceNumber.distance(from: a, to: b) == 10)
    }

    @Test("Distance backward simple")
    func distanceBackwardSimple() {
        let a = SequenceNumber(20)
        let b = SequenceNumber(10)
        #expect(SequenceNumber.distance(from: a, to: b) == -10)
    }

    @Test("Distance forward across wrap")
    func distanceForwardAcrossWrap() {
        let a = SequenceNumber(SequenceNumber.max - 4)
        let b = SequenceNumber(5)
        #expect(SequenceNumber.distance(from: a, to: b) == 10)
    }

    @Test("Distance backward across wrap")
    func distanceBackwardAcrossWrap() {
        let a = SequenceNumber(5)
        let b = SequenceNumber(SequenceNumber.max - 4)
        #expect(SequenceNumber.distance(from: a, to: b) == -10)
    }

    @Test("Distance from zero to one")
    func distanceZeroToOne() {
        let a = SequenceNumber(0)
        let b = SequenceNumber(1)
        #expect(SequenceNumber.distance(from: a, to: b) == 1)
    }

    @Test("Distance from max to zero (wrap)")
    func distanceMaxToZero() {
        let a = SequenceNumber(SequenceNumber.max)
        let b = SequenceNumber(0)
        #expect(SequenceNumber.distance(from: a, to: b) == 1)
    }

    @Test("Distance same value is zero")
    func distanceSame() {
        let sn = SequenceNumber(12345)
        #expect(SequenceNumber.distance(from: sn, to: sn) == 0)
    }

    @Test("Distance symmetry")
    func distanceSymmetry() {
        let a = SequenceNumber(100)
        let b = SequenceNumber(200)
        let d1 = SequenceNumber.distance(from: a, to: b)
        let d2 = SequenceNumber.distance(from: b, to: a)
        #expect(d1 == -d2)
    }

    // MARK: - Comparison

    @Test("Less than simple")
    func lessThanSimple() {
        let a = SequenceNumber(10)
        let b = SequenceNumber(20)
        #expect(a < b)
        #expect(!(b < a))
    }

    @Test("Less than across wrap boundary")
    func lessThanAcrossWrap() {
        let a = SequenceNumber(SequenceNumber.max - 5)
        let b = SequenceNumber(5)
        #expect(a < b)
    }

    @Test("Greater than across wrap boundary")
    func greaterThanAcrossWrap() {
        let a = SequenceNumber(5)
        let b = SequenceNumber(SequenceNumber.max - 5)
        #expect(b < a)
    }

    @Test("Equal values are not less than")
    func equalNotLessThan() {
        let a = SequenceNumber(42)
        let b = SequenceNumber(42)
        #expect(!(a < b))
        #expect(!(b < a))
    }

    // MARK: - Equality and Hashing

    @Test("Equality for same value")
    func equality() {
        let a = SequenceNumber(12345)
        let b = SequenceNumber(12345)
        #expect(a == b)
    }

    @Test("Inequality for different values")
    func inequality() {
        let a = SequenceNumber(100)
        let b = SequenceNumber(200)
        #expect(a != b)
    }

    @Test("Hash values match for equal sequence numbers")
    func hashConsistency() {
        let a = SequenceNumber(42)
        let b = SequenceNumber(42)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("Can be used in a Set")
    func setUsage() {
        let set: Set<SequenceNumber> = [SequenceNumber(1), SequenceNumber(2), SequenceNumber(1)]
        #expect(set.count == 2)
    }

    // MARK: - Description

    @Test("Description shows value")
    func descriptionOutput() {
        let sn = SequenceNumber(42)
        #expect(sn.description == "42")
    }

    // MARK: - Edge Cases

    @Test("Max plus 1 wraps to zero")
    func maxPlusOneWraps() {
        let sn = SequenceNumber(SequenceNumber.max)
        let result = sn + 1
        #expect(result.value == 0)
    }

    @Test("Zero minus 1 wraps to max")
    func zeroMinusOneWraps() {
        let sn = SequenceNumber(0)
        let result = sn - 1
        #expect(result.value == SequenceNumber.max)
    }

    @Test("Large positive offset wraps correctly")
    func largePositiveOffset() {
        let sn = SequenceNumber(0)
        let result = sn + Int32(SequenceNumber.max)
        #expect(result.value == SequenceNumber.max)
    }
}
