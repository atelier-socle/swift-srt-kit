// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Live mode congestion controller.
///
/// Pacing-based: sends packets at a fixed rate determined by MAX_BW.
/// Does not use a congestion window. Does not react to loss or timeouts.
/// This is the default mode for live streaming over SRT.
public struct LiveCC: CongestionController, Sendable {
    /// SRT header size in bytes (used in pacing calculation).
    public static let srtHeaderSize: Int = 16

    /// Configuration for LiveCC.
    public struct Configuration: Sendable {
        /// The bandwidth mode controlling MAX_BW.
        public let mode: MaxBandwidthMode

        /// Initial average payload size in bytes.
        public let initialPayloadSize: Int

        /// Creates a LiveCC configuration.
        ///
        /// - Parameters:
        ///   - mode: Bandwidth mode. Defaults to 1 Gbps direct.
        ///   - initialPayloadSize: Initial payload size in bytes. Defaults to 1316 (MPEG-TS × 7).
        public init(
            mode: MaxBandwidthMode = .direct(bitsPerSecond: 125_000_000),
            initialPayloadSize: Int = 1316
        ) {
            self.mode = mode
            self.initialPayloadSize = Swift.max(initialPayloadSize, 1)
        }
    }

    /// The LiveCC configuration.
    public let configuration: Configuration

    /// Current average payload size (EWMA-smoothed, in bytes).
    public private(set) var averagePayloadSize: Int

    /// Current estimated bandwidth from ACKs (bits/second), for auto mode.
    public private(set) var estimatedBandwidth: UInt64 = 0

    /// Algorithm name.
    public var name: String { "live" }

    /// Creates a LiveCC instance.
    ///
    /// - Parameter configuration: LiveCC configuration.
    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
        self.averagePayloadSize = configuration.initialPayloadSize
    }

    /// Records a sent packet and updates the average payload size.
    ///
    /// - Parameters:
    ///   - payloadSize: Size of the packet payload in bytes.
    ///   - timestamp: Packet timestamp in microseconds.
    public mutating func onPacketSent(payloadSize: Int, timestamp: UInt32) {
        // EWMA: (7 * avg + newSize) / 8
        averagePayloadSize = (7 * averagePayloadSize + payloadSize) / 8
    }

    /// ACK received — stores bandwidth estimate only (no rate adjustment).
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
        // Live mode: no rate adjustment on ACK
    }

    /// NAK received — no-op for live mode.
    ///
    /// - Parameter lossCount: Number of lost packets reported.
    public mutating func onNAK(lossCount: Int) {
        // Live mode: no rate reduction on loss
    }

    /// Timeout — no-op for live mode.
    public mutating func onTimeout() {
        // Live mode: no change on timeout
    }

    /// Current sending period in microseconds.
    ///
    /// Calculated as: `(AvgPayloadSize + 16) * 8 * 1_000_000 / MAX_BW`
    public func sendingPeriod() -> UInt64 {
        let maxBW = configuration.mode.effectiveBandwidth(estimatedBW: estimatedBandwidth)
        guard maxBW > 0 else { return 0 }
        let totalSize = UInt64(averagePayloadSize + Self.srtHeaderSize)
        return totalSize * 8 * 1_000_000 / maxBW
    }

    /// Returns nil — live mode is pacing-only, no congestion window.
    public func congestionWindow() -> Int? {
        nil
    }

    /// Returns the flow window size (no CWND constraint in live mode).
    ///
    /// - Parameters:
    ///   - flowWindowSize: Negotiated flow window size.
    ///   - peerAvailableBuffer: Peer's reported available buffer.
    /// - Returns: The flow window size.
    public func sendingWindow(flowWindowSize: Int, peerAvailableBuffer: Int) -> Int {
        flowWindowSize
    }

    /// Update estimated bandwidth from ACK data.
    ///
    /// - Parameter bitsPerSecond: Estimated bandwidth in bits/second.
    public mutating func updateEstimatedBandwidth(_ bitsPerSecond: UInt64) {
        estimatedBandwidth = bitsPerSecond
    }
}
