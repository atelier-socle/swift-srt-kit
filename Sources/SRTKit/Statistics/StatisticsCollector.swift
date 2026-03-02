// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Collects and aggregates statistics from protocol components.
///
/// Pure logic component — fed counters from the connection actor,
/// computes derived statistics, and tracks interval snapshots.
public struct StatisticsCollector: Sendable {
    // MARK: - Packet counts

    private var packetsSent: UInt64 = 0
    private var packetsReceived: UInt64 = 0
    private var packetsSentLost: UInt64 = 0
    private var packetsReceivedLost: UInt64 = 0
    private var packetsRetransmitted: UInt64 = 0
    private var acksSent: UInt64 = 0
    private var naksSent: UInt64 = 0
    private var packetsDropped: UInt64 = 0
    private var packetsFECRecovered: UInt64 = 0
    private var packetsDuplicate: UInt64 = 0

    // MARK: - Byte counts

    private var bytesSent: UInt64 = 0
    private var bytesReceived: UInt64 = 0
    private var bytesRetransmitted: UInt64 = 0
    private var bytesDropped: UInt64 = 0

    // MARK: - Timing

    private var rttMicroseconds: UInt64 = 0
    private var rttVarianceMicroseconds: UInt64 = 0

    // MARK: - Bandwidth

    private var bandwidthBitsPerSecond: UInt64 = 0
    private var sendRateBitsPerSecond: UInt64 = 0
    private var receiveRateBitsPerSecond: UInt64 = 0
    private var maxBandwidthBitsPerSecond: UInt64 = 0

    // MARK: - Buffers

    private var sendBufferPackets: Int = 0
    private var sendBufferCapacity: Int = 8192
    private var receiveBufferPackets: Int = 0
    private var receiveBufferCapacity: Int = 8192
    private var flowWindowAvailable: Int = 25600

    // MARK: - Congestion

    private var congestionWindowPackets: Int = 0
    private var sendingPeriodMicroseconds: UInt64 = 0
    private var packetsInFlight: Int = 0

    // MARK: - Encryption

    private var keyRotations: UInt64 = 0
    private var currentKeyIndex: Int = 0

    // MARK: - FEC

    private var fecPacketsSent: UInt64 = 0
    private var fecPacketsReceived: UInt64 = 0

    // MARK: - Connection

    private var startTime: UInt64 = 0

    /// Create a collector.
    public init() {}

    // MARK: - Recording methods

    /// Record a packet sent.
    public mutating func recordPacketSent(payloadSize: Int) {
        packetsSent += 1
        bytesSent += UInt64(payloadSize)
    }

    /// Record a packet received.
    public mutating func recordPacketReceived(payloadSize: Int) {
        packetsReceived += 1
        bytesReceived += UInt64(payloadSize)
    }

    /// Record a packet lost (sender-side, from NAK).
    public mutating func recordPacketLost() {
        packetsSentLost += 1
    }

    /// Record a packet loss detected on receive side.
    public mutating func recordReceiveLoss() {
        packetsReceivedLost += 1
    }

    /// Record a retransmission.
    public mutating func recordRetransmission(payloadSize: Int) {
        packetsRetransmitted += 1
        bytesRetransmitted += UInt64(payloadSize)
    }

    /// Record an ACK sent.
    public mutating func recordACKSent() {
        acksSent += 1
    }

    /// Record a NAK sent.
    public mutating func recordNAKSent() {
        naksSent += 1
    }

    /// Record a packet dropped (too late).
    public mutating func recordPacketDropped(payloadSize: Int) {
        packetsDropped += 1
        bytesDropped += UInt64(payloadSize)
    }

    /// Record an FEC recovery.
    public mutating func recordFECRecovery() {
        packetsFECRecovered += 1
    }

    /// Record a duplicate packet suppressed.
    public mutating func recordDuplicate() {
        packetsDuplicate += 1
    }

    /// Record a key rotation.
    public mutating func recordKeyRotation(newIndex: Int) {
        keyRotations += 1
        currentKeyIndex = newIndex
    }

    /// Record an FEC packet sent.
    public mutating func recordFECPacketSent() {
        fecPacketsSent += 1
    }

    /// Record an FEC packet received.
    public mutating func recordFECPacketReceived() {
        fecPacketsReceived += 1
    }

    // MARK: - Metric updates

    /// Update timing metrics.
    public mutating func updateTiming(
        rttMicroseconds: UInt64,
        rttVarianceMicroseconds: UInt64
    ) {
        self.rttMicroseconds = rttMicroseconds
        self.rttVarianceMicroseconds = rttVarianceMicroseconds
    }

    /// Update bandwidth metrics.
    public mutating func updateBandwidth(
        estimatedBitsPerSecond: UInt64,
        sendRateBitsPerSecond: UInt64,
        receiveRateBitsPerSecond: UInt64,
        maxBandwidthBitsPerSecond: UInt64
    ) {
        self.bandwidthBitsPerSecond = estimatedBitsPerSecond
        self.sendRateBitsPerSecond = sendRateBitsPerSecond
        self.receiveRateBitsPerSecond = receiveRateBitsPerSecond
        self.maxBandwidthBitsPerSecond = maxBandwidthBitsPerSecond
    }

    /// Update buffer metrics.
    public mutating func updateBuffers(
        sendBufferPackets: Int,
        sendBufferCapacity: Int,
        receiveBufferPackets: Int,
        receiveBufferCapacity: Int,
        flowWindowAvailable: Int
    ) {
        self.sendBufferPackets = sendBufferPackets
        self.sendBufferCapacity = sendBufferCapacity
        self.receiveBufferPackets = receiveBufferPackets
        self.receiveBufferCapacity = receiveBufferCapacity
        self.flowWindowAvailable = flowWindowAvailable
    }

    /// Update congestion metrics.
    public mutating func updateCongestion(
        windowPackets: Int,
        sendingPeriodMicroseconds: UInt64,
        packetsInFlight: Int
    ) {
        self.congestionWindowPackets = windowPackets
        self.sendingPeriodMicroseconds = sendingPeriodMicroseconds
        self.packetsInFlight = packetsInFlight
    }

    /// Set the connection start time.
    public mutating func setStartTime(_ time: UInt64) {
        startTime = time
    }

    // MARK: - Snapshots

    /// Generate a statistics snapshot.
    ///
    /// - Parameter currentTime: Current time in microseconds since connection start.
    /// - Returns: A complete statistics snapshot.
    public func snapshot(at currentTime: UInt64) -> SRTStatistics {
        SRTStatistics(
            packetsSent: packetsSent,
            packetsReceived: packetsReceived,
            packetsSentLost: packetsSentLost,
            packetsReceivedLost: packetsReceivedLost,
            packetsRetransmitted: packetsRetransmitted,
            acksSent: acksSent,
            naksSent: naksSent,
            packetsDropped: packetsDropped,
            packetsFECRecovered: packetsFECRecovered,
            packetsDuplicate: packetsDuplicate,
            bytesSent: bytesSent,
            bytesReceived: bytesReceived,
            bytesRetransmitted: bytesRetransmitted,
            bytesDropped: bytesDropped,
            rttMicroseconds: rttMicroseconds,
            rttVarianceMicroseconds: rttVarianceMicroseconds,
            bandwidthBitsPerSecond: bandwidthBitsPerSecond,
            sendRateBitsPerSecond: sendRateBitsPerSecond,
            receiveRateBitsPerSecond: receiveRateBitsPerSecond,
            maxBandwidthBitsPerSecond: maxBandwidthBitsPerSecond,
            sendBufferPackets: sendBufferPackets,
            sendBufferCapacity: sendBufferCapacity,
            receiveBufferPackets: receiveBufferPackets,
            receiveBufferCapacity: receiveBufferCapacity,
            flowWindowAvailable: flowWindowAvailable,
            congestionWindowPackets: congestionWindowPackets,
            sendingPeriodMicroseconds: sendingPeriodMicroseconds,
            packetsInFlight: packetsInFlight,
            uptimeMicroseconds: currentTime > startTime ? currentTime - startTime : 0,
            snapshotTimestamp: currentTime,
            keyRotations: keyRotations,
            currentKeyIndex: currentKeyIndex,
            fecPacketsSent: fecPacketsSent,
            fecPacketsReceived: fecPacketsReceived
        )
    }

    /// Generate a snapshot and reset interval counters.
    ///
    /// Keeps cumulative counters but resets interval-specific tracking.
    ///
    /// - Parameter currentTime: Current time in microseconds since connection start.
    /// - Returns: A complete statistics snapshot before reset.
    public mutating func snapshotAndReset(at currentTime: UInt64) -> SRTStatistics {
        let result = snapshot(at: currentTime)
        packetsSent = 0
        packetsReceived = 0
        packetsSentLost = 0
        packetsReceivedLost = 0
        packetsRetransmitted = 0
        acksSent = 0
        naksSent = 0
        packetsDropped = 0
        packetsFECRecovered = 0
        packetsDuplicate = 0
        bytesSent = 0
        bytesReceived = 0
        bytesRetransmitted = 0
        bytesDropped = 0
        fecPacketsSent = 0
        fecPacketsReceived = 0
        return result
    }
}
