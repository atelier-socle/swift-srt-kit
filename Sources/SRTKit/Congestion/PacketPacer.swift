// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Controls inter-packet sending intervals.
///
/// The pacer determines when the next packet can be sent based
/// on the congestion controller's sending period. It enforces
/// minimum spacing between packets to prevent bursts.
///
/// This is a pure logic component — it calculates timing but
/// does NOT schedule tasks or use timers. The connection actor
/// is responsible for using the pacer's output to schedule sends.
public struct PacketPacer: Sendable {
    /// Pacer decision.
    public enum Decision: Sendable, Equatable {
        /// Send the packet now.
        case sendNow
        /// Wait before sending. Returns µs to wait.
        case waitMicroseconds(UInt64)
    }

    /// Time of the last sent packet in microseconds.
    public private(set) var lastSendTime: UInt64?

    /// Number of packets sent through this pacer.
    public private(set) var packetsSent: Int = 0

    /// Creates a new packet pacer.
    public init() {}

    /// Check if a packet can be sent now.
    ///
    /// - Parameters:
    ///   - currentTime: Current time in microseconds.
    ///   - sendingPeriod: Required inter-packet interval in µs (from CC).
    /// - Returns: Decision to send or wait.
    public func canSend(currentTime: UInt64, sendingPeriod: UInt64) -> Decision {
        guard let lastTime = lastSendTime else {
            return .sendNow
        }
        guard sendingPeriod > 0 else {
            return .sendNow
        }
        guard currentTime > lastTime else {
            return .waitMicroseconds(sendingPeriod)
        }
        let elapsed = currentTime - lastTime
        if elapsed >= sendingPeriod {
            return .sendNow
        }
        return .waitMicroseconds(sendingPeriod - elapsed)
    }

    /// Record that a packet was sent.
    ///
    /// - Parameter sentAt: Time the packet was sent in microseconds.
    public mutating func packetSent(at sentAt: UInt64) {
        lastSendTime = sentAt
        packetsSent += 1
    }

    /// Check if this packet should be a probe pair packet.
    ///
    /// - Parameter probeInterval: Packets between probes (e.g., 16).
    /// - Returns: `true` if this packet is the first or second of a probe pair.
    public func isProbePacket(probeInterval: Int) -> Bool {
        guard probeInterval > 0 else { return false }
        let position = packetsSent % probeInterval
        return position == 0 || position == 1
    }

    /// Whether the current packet is the second of a probe pair.
    ///
    /// The second probe packet should be sent immediately after the first,
    /// back-to-back, ignoring the normal sending period.
    /// - Parameter probeInterval: Packets between probes (e.g., 16).
    /// - Returns: `true` if this packet is the second of a probe pair.
    public func isProbeSecond(probeInterval: Int) -> Bool {
        guard probeInterval > 0 else { return false }
        return packetsSent % probeInterval == 1
    }

    /// Reset pacer state.
    public mutating func reset() {
        lastSendTime = nil
        packetsSent = 0
    }
}
