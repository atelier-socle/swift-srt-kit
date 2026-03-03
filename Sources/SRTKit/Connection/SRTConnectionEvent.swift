// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Events emitted by an SRT connection.
public enum SRTConnectionEvent: Sendable {
    /// Connection state changed.
    case stateChanged(from: SRTConnectionState, to: SRTConnectionState)
    /// Handshake completed successfully.
    case handshakeComplete(peerSocketID: UInt32, negotiatedLatency: UInt64)
    /// Data received and ready for delivery.
    case dataReceived(payload: [UInt8], sequenceNumber: SequenceNumber)
    /// Packet recovered via FEC.
    case fecRecovery(sequenceNumber: SequenceNumber)
    /// Keepalive timeout — peer unresponsive.
    case keepaliveTimeout
    /// Connection broken.
    case connectionBroken(reason: String)
    /// Encryption key rotated.
    case keyRotated(newKeyIndex: KeyRotation.KeyIndex)
    /// Statistics snapshot.
    case statisticsUpdate
    /// Adaptive bitrate recommendation based on network conditions.
    case bitrateRecommendation(BitrateRecommendation)
    /// Recording statistics update.
    case recordingUpdate(RecordingStatistics)
}
