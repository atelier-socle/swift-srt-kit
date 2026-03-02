// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// File transfer congestion controller.
///
/// Uses AIMD (Additive Increase, Multiplicative Decrease) windowing
/// similar to TCP. Includes slow start phase for initial ramp-up.
public struct FileCC: CongestionController, Sendable {
    /// FileCC phase.
    public enum Phase: String, Sendable, CustomStringConvertible {
        /// Exponential growth until first loss.
        case slowStart
        /// Linear growth, multiplicative decrease on loss.
        case congestionAvoidance

        /// Human-readable description of the phase.
        public var description: String { rawValue }
    }

    /// Configuration for FileCC.
    public struct Configuration: Sendable {
        /// Initial congestion window size in packets.
        public let initialCWND: Int

        /// Minimum congestion window size in packets.
        public let minimumCWND: Int

        /// Multiplicative decrease factor (numerator/8).
        ///
        /// Default: 7 (i.e., 7/8 = 0.875 = decrease by 1/8).
        public let decreaseNumerator: Int

        /// Maximum congestion window size in packets.
        public let maximumCWND: Int

        /// Creates a FileCC configuration.
        ///
        /// - Parameters:
        ///   - initialCWND: Initial congestion window. Defaults to 16.
        ///   - minimumCWND: Minimum congestion window. Defaults to 2.
        ///   - decreaseNumerator: Multiplicative decrease numerator (over 8). Defaults to 7.
        ///   - maximumCWND: Maximum congestion window. Defaults to 8192.
        public init(
            initialCWND: Int = 16,
            minimumCWND: Int = 2,
            decreaseNumerator: Int = 7,
            maximumCWND: Int = 8192
        ) {
            self.initialCWND = Swift.max(initialCWND, 1)
            self.minimumCWND = Swift.max(minimumCWND, 1)
            self.decreaseNumerator = Swift.min(Swift.max(decreaseNumerator, 1), 7)
            self.maximumCWND = Swift.max(maximumCWND, self.minimumCWND)
        }
    }

    /// The FileCC configuration.
    public let configuration: Configuration

    /// Current phase (slow start or congestion avoidance).
    public private(set) var phase: Phase

    /// Current congestion window size (CWND) in packets.
    public private(set) var cwnd: Int

    /// Total number of loss events.
    public private(set) var lossEventCount: Int = 0

    /// Accumulator for additive increase in congestion avoidance.
    private var ackAccumulator: Int = 0

    /// Algorithm name.
    public var name: String { "file" }

    /// Creates a FileCC instance.
    ///
    /// - Parameter configuration: FileCC configuration.
    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
        self.phase = .slowStart
        self.cwnd = configuration.initialCWND
    }

    /// Records a sent packet — no-op for file mode.
    ///
    /// - Parameters:
    ///   - payloadSize: Size of the packet payload in bytes.
    ///   - timestamp: Packet timestamp in microseconds.
    public mutating func onPacketSent(payloadSize: Int, timestamp: UInt32) {
        // File mode: no payload-size tracking needed
    }

    /// ACK received — increases congestion window.
    ///
    /// In slow start: CWND += acknowledgedPackets.
    /// In congestion avoidance: approximately 1 packet per RTT.
    ///
    /// - Parameters:
    ///   - acknowledgedPackets: Number of newly acknowledged packets.
    ///   - rtt: Current smoothed RTT in microseconds.
    ///   - bandwidth: Estimated bandwidth in packets/second.
    ///   - availableBuffer: Peer's available buffer in packets.
    public mutating func onACK(
        acknowledgedPackets: Int,
        rtt: UInt64,
        bandwidth: UInt64,
        availableBuffer: Int
    ) {
        switch phase {
        case .slowStart:
            cwnd += acknowledgedPackets
            cwnd = Swift.min(cwnd, configuration.maximumCWND)
        case .congestionAvoidance:
            // Additive increase: ~1 packet per RTT
            ackAccumulator += acknowledgedPackets
            if ackAccumulator >= cwnd {
                cwnd += 1
                ackAccumulator -= cwnd
                cwnd = Swift.min(cwnd, configuration.maximumCWND)
            }
        }
    }

    /// NAK received — multiplicative decrease.
    ///
    /// In slow start: exits to congestion avoidance.
    /// CWND = CWND * decreaseNumerator / 8, clamped to minimumCWND.
    ///
    /// - Parameter lossCount: Number of lost packets reported.
    public mutating func onNAK(lossCount: Int) {
        lossEventCount += 1
        phase = .congestionAvoidance
        cwnd = Swift.max(cwnd * configuration.decreaseNumerator / 8, configuration.minimumCWND)
        ackAccumulator = 0
    }

    /// Timeout — same multiplicative decrease as NAK.
    public mutating func onTimeout() {
        lossEventCount += 1
        phase = .congestionAvoidance
        cwnd = Swift.max(cwnd * configuration.decreaseNumerator / 8, configuration.minimumCWND)
        ackAccumulator = 0
    }

    /// Returns 0 — file mode uses windowing, not pacing.
    public func sendingPeriod() -> UInt64 {
        0
    }

    /// Returns the current congestion window size.
    public func congestionWindow() -> Int? {
        cwnd
    }

    /// Returns the minimum of CWND, flow window, and peer buffer.
    ///
    /// - Parameters:
    ///   - flowWindowSize: Negotiated flow window size.
    ///   - peerAvailableBuffer: Peer's reported available buffer.
    /// - Returns: Effective sending window in packets.
    public func sendingWindow(flowWindowSize: Int, peerAvailableBuffer: Int) -> Int {
        Swift.min(cwnd, Swift.min(flowWindowSize, peerAvailableBuffer))
    }
}
