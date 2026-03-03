// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Typed events dispatched to congestion controllers.
///
/// Replaces individual method calls with a single event model,
/// enabling logging, replay, and plugin filtering.
public enum CongestionEvent: Sendable, Equatable {
    /// A packet was sent.
    case packetSent(size: Int, sequenceNumber: UInt32, timestamp: UInt64)

    /// An ACK was received.
    case ackReceived(
        ackSequence: UInt32,
        rttMicroseconds: UInt64,
        rttVarianceMicroseconds: UInt64,
        estimatedBandwidthBps: UInt64
    )

    /// A NAK was received (loss report).
    case nakReceived(lossSequences: [UInt32])

    /// A timeout occurred (no ACK for a while).
    case timeout(lastACKSequence: UInt32)

    /// Periodic tick (called every SYN_INTERVAL = 10ms).
    case tick(currentTime: UInt64)

    /// Connection established — initialize CC state.
    case connectionEstablished(initialRTTMicroseconds: UInt64)

    /// Connection closing — cleanup.
    case connectionClosing
}
