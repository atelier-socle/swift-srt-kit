// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Read-only snapshot of network state for CC decision-making.
///
/// Provided to the congestion controller on each event so it
/// has all the information needed without querying back.
public struct NetworkSnapshot: Sendable, Equatable {
    /// Smoothed RTT in microseconds.
    public let rttMicroseconds: UInt64

    /// RTT variance in microseconds.
    public let rttVarianceMicroseconds: UInt64

    /// Estimated bandwidth in bits/second.
    public let estimatedBandwidthBps: UInt64

    /// Current send rate in bits/second.
    public let sendRateBps: UInt64

    /// Maximum configured bandwidth (0 = unlimited).
    public let maxBandwidthBps: UInt64

    /// Current packet loss rate (0.0–1.0).
    public let lossRate: Double

    /// Packets currently in flight (sent, not ACKed).
    public let packetsInFlight: Int

    /// Send buffer utilization (0.0–1.0).
    public let sendBufferUtilization: Double

    /// Flow window available (packets).
    public let flowWindowAvailable: Int

    /// Connection uptime in microseconds.
    public let uptimeMicroseconds: UInt64

    /// Create a network snapshot.
    ///
    /// - Parameters:
    ///   - rttMicroseconds: Smoothed RTT.
    ///   - rttVarianceMicroseconds: RTT variance.
    ///   - estimatedBandwidthBps: Estimated bandwidth.
    ///   - sendRateBps: Current send rate.
    ///   - maxBandwidthBps: Maximum configured bandwidth.
    ///   - lossRate: Packet loss rate.
    ///   - packetsInFlight: Packets in flight.
    ///   - sendBufferUtilization: Send buffer utilization.
    ///   - flowWindowAvailable: Flow window available.
    ///   - uptimeMicroseconds: Connection uptime.
    public init(
        rttMicroseconds: UInt64 = 0,
        rttVarianceMicroseconds: UInt64 = 0,
        estimatedBandwidthBps: UInt64 = 0,
        sendRateBps: UInt64 = 0,
        maxBandwidthBps: UInt64 = 0,
        lossRate: Double = 0,
        packetsInFlight: Int = 0,
        sendBufferUtilization: Double = 0,
        flowWindowAvailable: Int = 25600,
        uptimeMicroseconds: UInt64 = 0
    ) {
        self.rttMicroseconds = rttMicroseconds
        self.rttVarianceMicroseconds = rttVarianceMicroseconds
        self.estimatedBandwidthBps = estimatedBandwidthBps
        self.sendRateBps = sendRateBps
        self.maxBandwidthBps = maxBandwidthBps
        self.lossRate = lossRate
        self.packetsInFlight = packetsInFlight
        self.sendBufferUtilization = sendBufferUtilization
        self.flowWindowAvailable = flowWindowAvailable
        self.uptimeMicroseconds = uptimeMicroseconds
    }
}
