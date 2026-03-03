// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTClock Tests")
struct SRTClockTests {
    // MARK: - SystemSRTClock

    @Test("SystemSRTClock now() returns non-zero value after brief delay")
    func systemClockNonZero() async throws {
        let clock = SystemSRTClock()
        // Small delay to ensure non-zero
        try await Task.sleep(for: .milliseconds(1))
        let time = clock.now()
        #expect(time > 0)
    }

    @Test("SystemSRTClock is monotonic")
    func systemClockMonotonic() {
        let clock = SystemSRTClock()
        let t1 = clock.now()
        // Tight loop to burn some time
        var sum: UInt64 = 0
        for i: UInt64 in 0..<1000 {
            sum += i
        }
        _ = sum
        let t2 = clock.now()
        #expect(t2 >= t1)
    }

    @Test("SystemSRTClock has microsecond precision")
    func systemClockPrecision() async throws {
        let clock = SystemSRTClock()
        let t1 = clock.now()
        try await Task.sleep(for: .milliseconds(10))
        let t2 = clock.now()
        let diff = t2 - t1
        // Should be roughly 10_000 µs (10ms), allow generous range for CI/Xcode overhead
        #expect(diff > 5_000)
        #expect(diff < 10_000_000)
    }

    // MARK: - MockSRTClock

    @Test("MockSRTClock initial time equals startTime")
    func mockClockInitialTime() {
        let clock = MockSRTClock(startTime: 42_000)
        #expect(clock.now() == 42_000)
    }

    @Test("MockSRTClock default startTime is 0")
    func mockClockDefaultStart() {
        let clock = MockSRTClock()
        #expect(clock.now() == 0)
    }

    @Test("MockSRTClock advance(by:) increases time correctly")
    func mockClockAdvance() {
        let clock = MockSRTClock()
        clock.advance(by: 10_000)
        #expect(clock.now() == 10_000)
    }

    @Test("MockSRTClock multiple advances accumulate")
    func mockClockMultipleAdvances() {
        let clock = MockSRTClock()
        clock.advance(by: 1_000)
        clock.advance(by: 2_000)
        clock.advance(by: 3_000)
        #expect(clock.now() == 6_000)
    }

    @Test("MockSRTClock set(to:) sets exact time")
    func mockClockSetTo() {
        let clock = MockSRTClock()
        clock.set(to: 99_999)
        #expect(clock.now() == 99_999)
    }

    @Test("MockSRTClock set(to:) can go backwards")
    func mockClockSetBackwards() {
        let clock = MockSRTClock(startTime: 100_000)
        clock.set(to: 50_000)
        #expect(clock.now() == 50_000)
    }

    @Test("MockSRTClock conforms to SRTClockProtocol")
    func mockClockProtocolConformance() {
        let clock: any SRTClockProtocol = MockSRTClock(startTime: 12_345)
        #expect(clock.now() == 12_345)
    }
}
