// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Detects and corrects clock drift between sender and receiver.
///
/// Uses a moving average of per-packet drift samples to detect
/// systematic clock drift, then applies gradual correction to
/// avoid jitter spikes.
///
/// All time values are in microseconds (µs).
public struct DriftManager: Sendable {
    /// Drift manager configuration.
    public struct Configuration: Sendable {
        /// Number of samples in the moving average window.
        public let windowSize: Int
        /// Maximum drift correction to apply per period (µs).
        /// Limits how fast drift is corrected to avoid jitter.
        public let maxCorrectionPerPeriod: Int64
        /// Minimum number of samples before applying correction.
        public let minSamplesForCorrection: Int

        /// Creates a drift manager configuration.
        ///
        /// - Parameters:
        ///   - windowSize: Number of samples in the moving average window.
        ///   - maxCorrectionPerPeriod: Maximum drift correction per period in µs.
        ///   - minSamplesForCorrection: Minimum samples before applying correction.
        public init(
            windowSize: Int = 100,
            maxCorrectionPerPeriod: Int64 = 5_000,
            minSamplesForCorrection: Int = 20
        ) {
            self.windowSize = Swift.max(windowSize, 1)
            self.maxCorrectionPerPeriod = maxCorrectionPerPeriod
            self.minSamplesForCorrection = Swift.max(minSamplesForCorrection, 1)
        }
    }

    /// The drift manager configuration.
    public let configuration: Configuration

    /// Circular buffer of drift samples.
    private var samples: [Int64]

    /// Write index into the circular buffer.
    private var writeIndex: Int = 0

    /// Number of samples collected (capped at windowSize).
    private var _sampleCount: Int = 0

    /// Running sum of samples in the window.
    private var runningSum: Int64 = 0

    /// Accumulated total drift correction (sum of all applied corrections).
    public private(set) var totalCorrection: Int64 = 0

    /// Creates a drift manager.
    ///
    /// - Parameter configuration: Drift manager configuration.
    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
        self.samples = [Int64](repeating: 0, count: configuration.windowSize)
    }

    /// Record a new drift sample from a received packet.
    ///
    /// - Parameters:
    ///   - senderTimestamp: Timestamp from the packet header (32-bit µs).
    ///   - receiveTime: Local clock time when the packet was received (µs).
    ///   - previousSenderTimestamp: Previous packet's sender timestamp.
    ///   - previousReceiveTime: Previous packet's receive time.
    public mutating func addSample(
        senderTimestamp: UInt32,
        receiveTime: UInt64,
        previousSenderTimestamp: UInt32,
        previousReceiveTime: UInt64
    ) {
        // Expected gap from sender timestamps (handles 32-bit wrap)
        let expectedGap = TimestampHelper.difference(senderTimestamp, previousSenderTimestamp)
        // Actual gap from receiver clock
        let actualGap = Int64(receiveTime) - Int64(previousReceiveTime)
        // Drift = actual - expected (positive = receiver faster)
        let drift = actualGap - expectedGap

        // If buffer is full, subtract the oldest sample from running sum
        if _sampleCount >= configuration.windowSize {
            runningSum -= samples[writeIndex]
        }

        // Write new sample
        samples[writeIndex] = drift
        runningSum += drift

        writeIndex = (writeIndex + 1) % configuration.windowSize
        if _sampleCount < configuration.windowSize {
            _sampleCount += 1
        }
    }

    /// Calculate the drift correction to apply.
    ///
    /// - Returns: Drift correction delta in microseconds (positive = receiver faster,
    ///   negative = receiver slower). Returns 0 if not enough samples.
    public func calculateCorrection() -> Int64 {
        guard hasEnoughSamples else { return 0 }
        let avg = averageDrift
        return clamp(avg, min: -configuration.maxCorrectionPerPeriod, max: configuration.maxCorrectionPerPeriod)
    }

    /// Apply the calculated correction and reset the sample window.
    ///
    /// - Returns: The correction that was applied.
    @discardableResult
    public mutating func applyCorrection() -> Int64 {
        let correction = calculateCorrection()
        totalCorrection += correction
        clearSamples()
        return correction
    }

    /// Current number of samples in the window.
    public var sampleCount: Int {
        _sampleCount
    }

    /// Current average drift per sample (µs).
    public var averageDrift: Int64 {
        guard _sampleCount > 0 else { return 0 }
        return runningSum / Int64(_sampleCount)
    }

    /// Whether enough samples have been collected to calculate correction.
    public var hasEnoughSamples: Bool {
        _sampleCount >= configuration.minSamplesForCorrection
    }

    /// Reset all state (e.g., on reconnection).
    public mutating func reset() {
        clearSamples()
        totalCorrection = 0
    }

    // MARK: - Private

    /// Clears the sample window without resetting totalCorrection.
    private mutating func clearSamples() {
        samples = [Int64](repeating: 0, count: configuration.windowSize)
        writeIndex = 0
        _sampleCount = 0
        runningSum = 0
    }

    /// Clamps a value to the given range.
    private func clamp(_ value: Int64, min minVal: Int64, max maxVal: Int64) -> Int64 {
        Swift.min(Swift.max(value, minVal), maxVal)
    }
}
