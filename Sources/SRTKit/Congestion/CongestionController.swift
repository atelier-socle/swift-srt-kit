// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Protocol for congestion control algorithms.
///
/// Implementations control packet sending rate through either
/// pacing (sending period) or windowing (congestion window), or both.
/// The protocol uses integer microsecond time values throughout.
public protocol CongestionController: Sendable {
    /// Algorithm name (e.g., "live", "file").
    var name: String { get }

    /// Notify that a data packet was sent.
    ///
    /// - Parameters:
    ///   - payloadSize: Size of the packet payload in bytes.
    ///   - timestamp: Packet timestamp in microseconds.
    mutating func onPacketSent(payloadSize: Int, timestamp: UInt32)

    /// Notify that an ACK was received.
    ///
    /// - Parameters:
    ///   - acknowledgedPackets: Number of newly acknowledged packets.
    ///   - rtt: Current smoothed RTT in microseconds.
    ///   - bandwidth: Estimated bandwidth in packets/second (from ACK).
    ///   - availableBuffer: Peer's available buffer in packets.
    mutating func onACK(
        acknowledgedPackets: Int,
        rtt: UInt64,
        bandwidth: UInt64,
        availableBuffer: Int
    )

    /// Notify that a NAK was received (loss detected).
    ///
    /// - Parameter lossCount: Number of lost packets reported.
    mutating func onNAK(lossCount: Int)

    /// Notify that a timeout occurred.
    mutating func onTimeout()

    /// Current sending period in microseconds.
    ///
    /// Returns the interval between consecutive packet sends.
    func sendingPeriod() -> UInt64

    /// Current congestion window in packets.
    ///
    /// Returns nil for pacing-only modes (LiveCC).
    func congestionWindow() -> Int?

    /// The effective sending window considering all constraints.
    ///
    /// - Parameters:
    ///   - flowWindowSize: Negotiated flow window size.
    ///   - peerAvailableBuffer: Peer's reported available buffer.
    /// - Returns: Maximum packets that can be in-flight.
    func sendingWindow(flowWindowSize: Int, peerAvailableBuffer: Int) -> Int
}
