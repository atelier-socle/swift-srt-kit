// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Comprehensive SRT connection statistics.
///
/// Models all performance metrics tracked by the SRT protocol,
/// matching the fields from libsrt's SRT_TRACEBSTATS structure.
public struct SRTStatistics: Sendable, Equatable {
    // MARK: - Packet counts

    /// Total data packets sent.
    public var packetsSent: UInt64

    /// Total data packets received.
    public var packetsReceived: UInt64

    /// Total unique packets lost (sender-side, via NAK reports).
    public var packetsSentLost: UInt64

    /// Total packets lost on receive side (detected gaps).
    public var packetsReceivedLost: UInt64

    /// Total packets retransmitted.
    public var packetsRetransmitted: UInt64

    /// Total ACK packets sent.
    public var acksSent: UInt64

    /// Total NAK packets sent.
    public var naksSent: UInt64

    /// Total packets dropped (too late).
    public var packetsDropped: UInt64

    /// Total packets recovered via FEC.
    public var packetsFECRecovered: UInt64

    /// Total duplicate packets suppressed (bonding).
    public var packetsDuplicate: UInt64

    // MARK: - Byte counts

    /// Total bytes sent (payload only).
    public var bytesSent: UInt64

    /// Total bytes received (payload only).
    public var bytesReceived: UInt64

    /// Total bytes retransmitted.
    public var bytesRetransmitted: UInt64

    /// Total bytes dropped.
    public var bytesDropped: UInt64

    // MARK: - Timing (microseconds)

    /// Smoothed round-trip time in microseconds.
    public var rttMicroseconds: UInt64

    /// RTT variance in microseconds.
    public var rttVarianceMicroseconds: UInt64

    /// Negotiated TSBPD latency in microseconds.
    public var negotiatedLatency: UInt64

    // MARK: - Bandwidth

    /// Estimated bandwidth in bits/second.
    public var bandwidthBitsPerSecond: UInt64

    /// Current send rate in bits/second.
    public var sendRateBitsPerSecond: UInt64

    /// Current receive rate in bits/second.
    public var receiveRateBitsPerSecond: UInt64

    /// Maximum configured bandwidth in bits/second (0 = unlimited).
    public var maxBandwidthBitsPerSecond: UInt64

    // MARK: - Buffers

    /// Packets currently in send buffer.
    public var sendBufferPackets: Int

    /// Total send buffer capacity in packets.
    public var sendBufferCapacity: Int

    /// Packets currently in receive buffer.
    public var receiveBufferPackets: Int

    /// Total receive buffer capacity in packets.
    public var receiveBufferCapacity: Int

    /// Flow window available (packets).
    public var flowWindowAvailable: Int

    // MARK: - Congestion

    /// Congestion window size in packets.
    public var congestionWindowPackets: Int

    /// Sending period in microseconds (inter-packet interval).
    public var sendingPeriodMicroseconds: UInt64

    /// Packets in flight (sent but not ACKed).
    public var packetsInFlight: Int

    // MARK: - Connection

    /// Connection uptime in microseconds.
    public var uptimeMicroseconds: UInt64

    /// Timestamp of this statistics snapshot (microseconds since connection start).
    public var snapshotTimestamp: UInt64

    // MARK: - Encryption

    /// Number of key rotations performed.
    public var keyRotations: UInt64

    /// Current encryption key index (even=0, odd=1).
    public var currentKeyIndex: Int

    // MARK: - FEC

    /// Total FEC packets sent.
    public var fecPacketsSent: UInt64

    /// Total FEC packets received.
    public var fecPacketsReceived: UInt64

    // MARK: - Computed

    /// Packet loss rate (0.0–1.0).
    public var lossRate: Double {
        let total = packetsSent + packetsReceived
        guard total > 0 else { return 0 }
        return Double(packetsSentLost + packetsReceivedLost) / Double(total)
    }

    /// Send buffer utilization (0.0–1.0).
    public var sendBufferUtilization: Double {
        guard sendBufferCapacity > 0 else { return 0 }
        return Double(sendBufferPackets) / Double(sendBufferCapacity)
    }

    /// Receive buffer utilization (0.0–1.0).
    public var receiveBufferUtilization: Double {
        guard receiveBufferCapacity > 0 else { return 0 }
        return Double(receiveBufferPackets) / Double(receiveBufferCapacity)
    }

    /// Create empty statistics (all zeros).
    public init() {
        self.packetsSent = 0
        self.packetsReceived = 0
        self.packetsSentLost = 0
        self.packetsReceivedLost = 0
        self.packetsRetransmitted = 0
        self.acksSent = 0
        self.naksSent = 0
        self.packetsDropped = 0
        self.packetsFECRecovered = 0
        self.packetsDuplicate = 0
        self.bytesSent = 0
        self.bytesReceived = 0
        self.bytesRetransmitted = 0
        self.bytesDropped = 0
        self.rttMicroseconds = 0
        self.rttVarianceMicroseconds = 0
        self.negotiatedLatency = 0
        self.bandwidthBitsPerSecond = 0
        self.sendRateBitsPerSecond = 0
        self.receiveRateBitsPerSecond = 0
        self.maxBandwidthBitsPerSecond = 0
        self.sendBufferPackets = 0
        self.sendBufferCapacity = 8192
        self.receiveBufferPackets = 0
        self.receiveBufferCapacity = 8192
        self.flowWindowAvailable = 25600
        self.congestionWindowPackets = 0
        self.sendingPeriodMicroseconds = 0
        self.packetsInFlight = 0
        self.uptimeMicroseconds = 0
        self.snapshotTimestamp = 0
        self.keyRotations = 0
        self.currentKeyIndex = 0
        self.fecPacketsSent = 0
        self.fecPacketsReceived = 0
    }

    /// Create statistics with specific values.
    public init(
        packetsSent: UInt64 = 0,
        packetsReceived: UInt64 = 0,
        packetsSentLost: UInt64 = 0,
        packetsReceivedLost: UInt64 = 0,
        packetsRetransmitted: UInt64 = 0,
        acksSent: UInt64 = 0,
        naksSent: UInt64 = 0,
        packetsDropped: UInt64 = 0,
        packetsFECRecovered: UInt64 = 0,
        packetsDuplicate: UInt64 = 0,
        bytesSent: UInt64 = 0,
        bytesReceived: UInt64 = 0,
        bytesRetransmitted: UInt64 = 0,
        bytesDropped: UInt64 = 0,
        rttMicroseconds: UInt64 = 0,
        rttVarianceMicroseconds: UInt64 = 0,
        negotiatedLatency: UInt64 = 0,
        bandwidthBitsPerSecond: UInt64 = 0,
        sendRateBitsPerSecond: UInt64 = 0,
        receiveRateBitsPerSecond: UInt64 = 0,
        maxBandwidthBitsPerSecond: UInt64 = 0,
        sendBufferPackets: Int = 0,
        sendBufferCapacity: Int = 8192,
        receiveBufferPackets: Int = 0,
        receiveBufferCapacity: Int = 8192,
        flowWindowAvailable: Int = 25600,
        congestionWindowPackets: Int = 0,
        sendingPeriodMicroseconds: UInt64 = 0,
        packetsInFlight: Int = 0,
        uptimeMicroseconds: UInt64 = 0,
        snapshotTimestamp: UInt64 = 0,
        keyRotations: UInt64 = 0,
        currentKeyIndex: Int = 0,
        fecPacketsSent: UInt64 = 0,
        fecPacketsReceived: UInt64 = 0
    ) {
        self.packetsSent = packetsSent
        self.packetsReceived = packetsReceived
        self.packetsSentLost = packetsSentLost
        self.packetsReceivedLost = packetsReceivedLost
        self.packetsRetransmitted = packetsRetransmitted
        self.acksSent = acksSent
        self.naksSent = naksSent
        self.packetsDropped = packetsDropped
        self.packetsFECRecovered = packetsFECRecovered
        self.packetsDuplicate = packetsDuplicate
        self.bytesSent = bytesSent
        self.bytesReceived = bytesReceived
        self.bytesRetransmitted = bytesRetransmitted
        self.bytesDropped = bytesDropped
        self.rttMicroseconds = rttMicroseconds
        self.rttVarianceMicroseconds = rttVarianceMicroseconds
        self.negotiatedLatency = negotiatedLatency
        self.bandwidthBitsPerSecond = bandwidthBitsPerSecond
        self.sendRateBitsPerSecond = sendRateBitsPerSecond
        self.receiveRateBitsPerSecond = receiveRateBitsPerSecond
        self.maxBandwidthBitsPerSecond = maxBandwidthBitsPerSecond
        self.sendBufferPackets = sendBufferPackets
        self.sendBufferCapacity = sendBufferCapacity
        self.receiveBufferPackets = receiveBufferPackets
        self.receiveBufferCapacity = receiveBufferCapacity
        self.flowWindowAvailable = flowWindowAvailable
        self.congestionWindowPackets = congestionWindowPackets
        self.sendingPeriodMicroseconds = sendingPeriodMicroseconds
        self.packetsInFlight = packetsInFlight
        self.uptimeMicroseconds = uptimeMicroseconds
        self.snapshotTimestamp = snapshotTimestamp
        self.keyRotations = keyRotations
        self.currentKeyIndex = currentKeyIndex
        self.fecPacketsSent = fecPacketsSent
        self.fecPacketsReceived = fecPacketsReceived
    }
}
