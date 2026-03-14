// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - PacketPipeline nested types

extension PacketPipeline {
    /// Result of processing a received data packet.
    public enum ReceiveResult: Sendable {
        /// Packet buffered, waiting for delivery time.
        case buffered
        /// One or more packets ready for delivery.
        case deliver(payloads: [DeliveredPacket])
        /// Packet is a duplicate.
        case duplicate
        /// Packet dropped (too late).
        case tooLate
    }

    /// A delivered packet with sequence number and payload.
    public struct DeliveredPacket: Sendable {
        /// The packet's sequence number.
        public let sequenceNumber: SequenceNumber
        /// The packet payload.
        public let payload: [UInt8]
    }

    /// Result of processing a send request.
    public enum SendResult: Sendable {
        /// Packet(s) ready to transmit.
        case transmit(packets: [SRTPacketData])
        /// Send buffer full, cannot accept now.
        case bufferFull
    }

    /// Packet data ready for network transmission.
    public struct SRTPacketData: Sendable {
        /// The packet payload.
        public let payload: [UInt8]
        /// The packet's sequence number.
        public let sequenceNumber: SequenceNumber
        /// The packet timestamp.
        public let timestamp: UInt32
        /// Whether this is a retransmission.
        public let isRetransmit: Bool
        /// Whether this is an FEC packet.
        public let isFEC: Bool

        /// Creates a packet data.
        ///
        /// - Parameters:
        ///   - payload: The packet payload.
        ///   - sequenceNumber: The packet's sequence number.
        ///   - timestamp: The packet timestamp.
        ///   - isRetransmit: Whether this is a retransmission.
        ///   - isFEC: Whether this is an FEC packet.
        public init(
            payload: [UInt8],
            sequenceNumber: SequenceNumber,
            timestamp: UInt32,
            isRetransmit: Bool = false,
            isFEC: Bool = false
        ) {
            self.payload = payload
            self.sequenceNumber = sequenceNumber
            self.timestamp = timestamp
            self.isRetransmit = isRetransmit
            self.isFEC = isFEC
        }
    }

    /// Pipeline configuration.
    public struct Configuration: Sendable {
        /// Whether encryption is enabled.
        public let encryptionEnabled: Bool
        /// Whether FEC is enabled.
        public let fecEnabled: Bool
        /// FEC configuration (when FEC is enabled).
        public let fecConfiguration: FECConfiguration?
        /// Cipher mode for encryption.
        public let cipherMode: CipherMode
        /// Latency in microseconds for TSBPD.
        public let latencyMicroseconds: UInt64
        /// Initial sequence number for the receive buffer (peer's ISN).
        public let initialSequenceNumber: SequenceNumber
        /// Initial sequence number for outgoing packets (local ISN).
        public let sendInitialSequenceNumber: SequenceNumber
        /// Send buffer capacity.
        public let sendBufferCapacity: Int

        /// Creates a pipeline configuration.
        ///
        /// - Parameters:
        ///   - encryptionEnabled: Whether encryption is enabled.
        ///   - fecEnabled: Whether FEC is enabled.
        ///   - fecConfiguration: FEC configuration.
        ///   - cipherMode: Cipher mode.
        ///   - latencyMicroseconds: Latency in microseconds.
        ///   - initialSequenceNumber: Initial sequence number for receiving.
        ///   - sendInitialSequenceNumber: Initial sequence number for sending.
        ///   - sendBufferCapacity: Send buffer capacity.
        public init(
            encryptionEnabled: Bool = false,
            fecEnabled: Bool = false,
            fecConfiguration: FECConfiguration? = nil,
            cipherMode: CipherMode = .ctr,
            latencyMicroseconds: UInt64 = 120_000,
            initialSequenceNumber: SequenceNumber = SequenceNumber(0),
            sendInitialSequenceNumber: SequenceNumber = SequenceNumber(0),
            sendBufferCapacity: Int = 8192
        ) {
            self.encryptionEnabled = encryptionEnabled
            self.fecEnabled = fecEnabled
            self.fecConfiguration = fecConfiguration
            self.cipherMode = cipherMode
            self.latencyMicroseconds = latencyMicroseconds
            self.initialSequenceNumber = initialSequenceNumber
            self.sendInitialSequenceNumber = sendInitialSequenceNumber
            self.sendBufferCapacity = sendBufferCapacity
        }
    }
}
