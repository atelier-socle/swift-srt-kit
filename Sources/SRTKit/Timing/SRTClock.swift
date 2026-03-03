// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(os)
    import os
#else
    import NIOConcurrencyHelpers
#endif

/// Protocol for a microsecond-precision clock.
///
/// Abstracts the system clock to enable deterministic testing
/// without real-time delays. Production code uses ``SystemSRTClock``,
/// tests use ``MockSRTClock``.
public protocol SRTClockProtocol: Sendable {
    /// Current time in microseconds.
    func now() -> UInt64
}

/// System clock implementation using ContinuousClock (monotonic).
///
/// Provides microsecond-precision timestamps that don't jump
/// on system clock adjustments (NTP, manual changes).
public struct SystemSRTClock: SRTClockProtocol, Sendable {
    /// The continuous clock instant captured at initialization.
    private let origin: ContinuousClock.Instant

    /// Creates a new system clock anchored to the current time.
    public init() {
        self.origin = ContinuousClock.now
    }

    /// Returns the current time in microseconds since this clock was created.
    public func now() -> UInt64 {
        let elapsed = origin.duration(to: ContinuousClock.now)
        let (seconds, attoseconds) = elapsed.components
        let microseconds =
            UInt64(seconds) * 1_000_000
            + UInt64(attoseconds) / 1_000_000_000_000
        return microseconds
    }
}

/// Mock clock for deterministic testing.
///
/// Allows tests to control time precisely, advancing it
/// manually without real-time delays. Uses `OSAllocatedUnfairLock`
/// on Apple platforms and `NIOLockedValueBox` on Linux for
/// thread-safe `Sendable` conformance.
public final class MockSRTClock: SRTClockProtocol, Sendable {
    /// Thread-safe time storage.
    #if canImport(os)
        private let _time: OSAllocatedUnfairLock<UInt64>
    #else
        private let _time: NIOLockedValueBox<UInt64>
    #endif

    /// Creates a mock clock starting at the specified time.
    ///
    /// - Parameter startTime: Initial time in microseconds.
    public init(startTime: UInt64 = 0) {
        #if canImport(os)
            self._time = OSAllocatedUnfairLock(initialState: startTime)
        #else
            self._time = NIOLockedValueBox(startTime)
        #endif
    }

    /// Returns the current mock time in microseconds.
    public func now() -> UInt64 {
        #if canImport(os)
            _time.withLock { $0 }
        #else
            _time.withLockedValue { $0 }
        #endif
    }

    /// Advance the clock by the specified microseconds.
    ///
    /// - Parameter microseconds: Duration to advance.
    public func advance(by microseconds: UInt64) {
        #if canImport(os)
            _time.withLock { $0 += microseconds }
        #else
            _time.withLockedValue { $0 += microseconds }
        #endif
    }

    /// Set the clock to a specific time.
    ///
    /// - Parameter microseconds: Exact time to set.
    public func set(to microseconds: UInt64) {
        #if canImport(os)
            _time.withLock { $0 = microseconds }
        #else
            _time.withLockedValue { $0 = microseconds }
        #endif
    }
}
