// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Actions produced by the reliability layer for the connection to execute.
///
/// The reliability layer is pure logic — it produces actions that the
/// connection layer translates into actual network I/O.
public enum ReliabilityAction: Sendable {
    /// Send a full ACK control packet.
    case sendFullACK(
        ackSequenceNumber: UInt32,
        lastACKedSequence: SequenceNumber,
        rtt: UInt64,
        rttVariance: UInt64,
        availableBuffer: Int,
        receivingRate: Int,
        bandwidth: Int,
        receivingByteRate: Int
    )
    /// Send a light ACK control packet.
    case sendLightACK(lastACKedSequence: SequenceNumber)
    /// Send an ACKACK response.
    case sendACKACK(ackSequenceNumber: UInt32)
    /// Send a NAK with the loss list.
    case sendNAK(lostSequenceNumbers: [SequenceNumber])
    /// Retransmit packets (R flag = 1).
    case retransmit(packets: [RetransmissionManager.RetransmitRequest])
    /// Deliver received packets to the application layer (in order).
    case deliver(packets: [ReceiveBuffer.ReceivedPacket])
    /// Drop request — inform peer that packets were dropped.
    case sendDropRequest(
        firstSequence: SequenceNumber,
        lastSequence: SequenceNumber,
        messageNumber: UInt32
    )
}
