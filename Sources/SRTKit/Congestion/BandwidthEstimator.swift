// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Estimates link bandwidth using packet-pair probing.
///
/// The receiver tracks arrival times of probe packet pairs
/// (every 16 packets) and estimates bandwidth from the
/// inter-arrival times. A median filter discards outliers.
public struct BandwidthEstimator: Sendable {
    /// Configuration for bandwidth estimation.
    public struct Configuration: Sendable {
        /// Packets between probe pairs.
        public let probeInterval: Int

        /// Number of estimates to keep for median filter.
        public let windowSize: Int

        /// Minimum inter-arrival time in µs to consider valid.
        public let minInterArrival: UInt64

        /// Creates a bandwidth estimator configuration.
        ///
        /// - Parameters:
        ///   - probeInterval: Packets between probe pairs. Defaults to 16.
        ///   - windowSize: Estimate window size. Defaults to 16.
        ///   - minInterArrival: Minimum inter-arrival in µs. Defaults to 1.
        public init(
            probeInterval: Int = 16,
            windowSize: Int = 16,
            minInterArrival: UInt64 = 1
        ) {
            self.probeInterval = Swift.max(probeInterval, 1)
            self.windowSize = Swift.max(windowSize, 1)
            self.minInterArrival = minInterArrival
        }
    }

    /// The estimator configuration.
    public let configuration: Configuration

    /// Circular buffer of bandwidth estimates (bits/second).
    private var estimates: [UInt64]

    /// Write index into the circular buffer.
    private var writeIndex: Int = 0

    /// Number of estimates collected (capped at windowSize).
    private var _estimateCount: Int = 0

    /// Receive time of the first packet in the current probe pair.
    private var firstProbeReceiveTime: UInt64?

    /// Creates a bandwidth estimator.
    ///
    /// - Parameter configuration: Estimator configuration.
    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
        self.estimates = [UInt64](repeating: 0, count: configuration.windowSize)
    }

    /// Record a received probe packet.
    ///
    /// - Parameters:
    ///   - packetSize: Packet size in bytes (payload + header).
    ///   - receiveTime: Local receive time in microseconds.
    ///   - isSecondOfPair: Whether this is the second packet in a probe pair.
    public mutating func recordProbePacket(
        packetSize: Int,
        receiveTime: UInt64,
        isSecondOfPair: Bool
    ) {
        if !isSecondOfPair {
            // First of pair: record time
            firstProbeReceiveTime = receiveTime
            return
        }

        // Second of pair: calculate estimate
        guard let firstTime = firstProbeReceiveTime else { return }
        firstProbeReceiveTime = nil

        guard receiveTime > firstTime else { return }
        let interArrival = receiveTime - firstTime

        guard interArrival >= configuration.minInterArrival else { return }

        // estimate = packetSize * 8 * 1_000_000 / interArrival  (bits/second)
        let estimate = UInt64(packetSize) * 8 * 1_000_000 / interArrival

        estimates[writeIndex] = estimate
        writeIndex = (writeIndex + 1) % configuration.windowSize
        if _estimateCount < configuration.windowSize {
            _estimateCount += 1
        }
    }

    /// Current estimated bandwidth in bits/second.
    ///
    /// Uses median filter over recent probe estimates.
    public var estimatedBandwidth: UInt64 {
        guard _estimateCount > 0 else { return 0 }
        let active = Array(estimates.prefix(_estimateCount)).sorted()
        return active[active.count / 2]
    }

    /// Current estimated link capacity in packets/second.
    ///
    /// - Parameter avgPacketSize: Average packet size in bytes.
    /// - Returns: Estimated capacity in packets/second.
    public func estimatedCapacity(avgPacketSize: Int) -> UInt64 {
        guard avgPacketSize > 0 else { return 0 }
        return estimatedBandwidth / UInt64(avgPacketSize * 8)
    }

    /// Number of probe estimates collected.
    public var estimateCount: Int {
        _estimateCount
    }

    /// Whether enough probes have been collected for a reliable estimate.
    public var hasReliableEstimate: Bool {
        _estimateCount >= configuration.windowSize / 2
    }

    /// Reset all collected estimates.
    public mutating func reset() {
        estimates = [UInt64](repeating: 0, count: configuration.windowSize)
        writeIndex = 0
        _estimateCount = 0
        firstProbeReceiveTime = nil
    }
}
