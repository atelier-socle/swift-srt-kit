// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Manages Timestamp-Based Packet Delivery (TSBPD).
///
/// Calculates when packets should be delivered to the application
/// layer based on their sender timestamps, the negotiated latency,
/// and accumulated drift correction.
///
/// All time values are in microseconds (µs).
public struct TSBPDManager: Sendable {
    /// TSBPD configuration.
    public struct Configuration: Sendable {
        /// Negotiated latency in microseconds.
        public let latencyMicroseconds: UInt64
        /// Whether TSBPD is enabled (live mode = true, file mode = false).
        public let enabled: Bool
        /// Whether too-late packet drop is enabled.
        public let tooLateDropEnabled: Bool

        /// Creates a TSBPD configuration.
        ///
        /// - Parameters:
        ///   - latencyMicroseconds: Negotiated latency in microseconds (default: 120ms).
        ///   - enabled: Whether TSBPD is enabled.
        ///   - tooLateDropEnabled: Whether too-late packet drop is enabled.
        public init(
            latencyMicroseconds: UInt64 = 120_000,
            enabled: Bool = true,
            tooLateDropEnabled: Bool = true
        ) {
            self.latencyMicroseconds = latencyMicroseconds
            self.enabled = enabled
            self.tooLateDropEnabled = tooLateDropEnabled
        }
    }

    /// Delivery decision for a packet.
    public enum DeliveryDecision: Sendable, Equatable {
        /// Packet is ready for delivery now.
        case deliver
        /// Packet should wait — returns microseconds until delivery.
        case wait(microseconds: UInt64)
        /// Packet is too late — should be dropped (only if tooLateDropEnabled).
        case tooLate
        /// TSBPD is disabled — deliver immediately.
        case immediate
    }

    /// The TSBPD configuration.
    public let configuration: Configuration

    /// The base time offset mapping sender timestamps to local clock.
    ///
    /// `baseTime = localTimeAtConnection - firstTimestamp`
    public let baseTime: UInt64

    /// Create a TSBPD manager.
    ///
    /// - Parameters:
    ///   - configuration: TSBPD settings.
    ///   - baseTime: Local clock time when connection was established (µs).
    ///   - firstTimestamp: First sender timestamp received (µs).
    public init(
        configuration: Configuration,
        baseTime: UInt64,
        firstTimestamp: UInt32
    ) {
        self.configuration = configuration
        // Map sender timestamp space to local clock space
        if baseTime >= UInt64(firstTimestamp) {
            self.baseTime = baseTime - UInt64(firstTimestamp)
        } else {
            // Handle case where firstTimestamp > baseTime (unlikely but safe)
            self.baseTime = 0
        }
    }

    /// Calculate the local delivery time for a packet.
    ///
    /// - Parameters:
    ///   - packetTimestamp: The sender's timestamp from the data packet header (32-bit µs).
    ///   - driftCorrection: Current accumulated drift correction (µs, signed).
    /// - Returns: Local clock time when this packet should be delivered (µs).
    public func deliveryTime(
        packetTimestamp: UInt32,
        driftCorrection: Int64
    ) -> UInt64 {
        let rawTime = baseTime + UInt64(packetTimestamp) + configuration.latencyMicroseconds
        if driftCorrection >= 0 {
            return rawTime + UInt64(driftCorrection)
        }
        let absDrift = UInt64(-driftCorrection)
        return rawTime > absDrift ? rawTime - absDrift : 0
    }

    /// Check if a packet is ready for delivery.
    ///
    /// - Parameters:
    ///   - packetTimestamp: The sender's timestamp.
    ///   - currentTime: Current local time (µs).
    ///   - driftCorrection: Current drift correction.
    /// - Returns: Delivery decision.
    public func deliveryDecision(
        packetTimestamp: UInt32,
        currentTime: UInt64,
        driftCorrection: Int64
    ) -> DeliveryDecision {
        guard configuration.enabled else {
            return .immediate
        }

        let targetTime = deliveryTime(
            packetTimestamp: packetTimestamp,
            driftCorrection: driftCorrection
        )

        if currentTime >= targetTime {
            // Check how late
            let lateness = currentTime - targetTime
            if lateness > 0 && configuration.tooLateDropEnabled {
                return .tooLate
            }
            return .deliver
        }

        let waitTime = targetTime - currentTime
        return .wait(microseconds: waitTime)
    }
}
