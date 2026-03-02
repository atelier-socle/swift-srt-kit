// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Coordinates the send and receive packet processing pipeline.
///
/// This struct holds references to all protocol components and
/// provides methods that process packets through the full chain.
/// It is a value type owned by the SRTSocket actor.
public struct PacketPipeline: Sendable {
    /// The pipeline configuration.
    public let configuration: Configuration

    // MARK: - Protocol components

    /// Send buffer for reliability.
    private var sendBuffer: SendBuffer

    /// Receive buffer for reordering and gap detection.
    private var receiveBuffer: ReceiveBuffer

    /// ACK generation manager.
    private var ackManager: ACKManager

    /// RTT estimator.
    private var rttEstimator: RTTEstimator

    /// Retransmission manager.
    private var retransmissionManager: RetransmissionManager

    /// Loss detector.
    private var lossDetector: LossDetector

    /// Drift correction manager.
    private var driftManager: DriftManager

    /// Too-late packet drop handler.
    private var tooLateDrop: TooLatePacketDrop

    /// TSBPD delivery manager (created on first packet).
    private var tsbpdManager: TSBPDManager?

    /// Encryptor (configured after handshake).
    private var encryptor: SRTEncryptor?

    /// Decryptor (configured after handshake).
    private var decryptor: SRTDecryptor?

    /// FEC encoder (when FEC is enabled).
    private var fecEncoder: FECEncoder?

    /// FEC decoder (when FEC is enabled).
    private var fecDecoder: FECDecoder?

    /// Next sequence number to assign to outgoing packets.
    private var nextSequenceNumber: SequenceNumber

    /// Next message number to assign.
    private var nextMessageNumber: UInt32 = 0

    /// Packets delivered from receive buffer awaiting TSBPD timing.
    private var pendingDelivery: [ReceiveBuffer.ReceivedPacket] = []

    // MARK: - Stats

    /// Number of packets sent.
    private var packetsSentCount: Int = 0

    /// Number of packets delivered to the application.
    private var packetsDeliveredCount: Int = 0

    /// Number of packets recovered via FEC.
    private var fecRecoveriesCount: Int = 0

    /// Number of retransmissions performed.
    private var retransmissionsCount: Int = 0

    /// Creates a packet pipeline.
    ///
    /// - Parameter configuration: The pipeline configuration.
    public init(configuration: Configuration) {
        self.configuration = configuration
        self.sendBuffer = SendBuffer(capacity: configuration.sendBufferCapacity)
        self.receiveBuffer = ReceiveBuffer(
            initialSequenceNumber: configuration.initialSequenceNumber)
        self.ackManager = ACKManager()
        self.rttEstimator = RTTEstimator()
        self.retransmissionManager = RetransmissionManager()
        self.lossDetector = LossDetector()
        self.driftManager = DriftManager()
        self.tooLateDrop = TooLatePacketDrop()
        self.nextSequenceNumber = configuration.initialSequenceNumber

        if configuration.fecEnabled, let fecConfig = configuration.fecConfiguration {
            self.fecEncoder = FECEncoder(configuration: fecConfig)
            self.fecDecoder = FECDecoder(configuration: fecConfig)
        }
    }

    // MARK: - Receive path

    /// Process a received data packet through the full receive pipeline.
    ///
    /// Pipeline: decrypt → reliability (receive buffer) → queue for TSBPD.
    /// - Parameters:
    ///   - payload: The raw packet payload.
    ///   - sequenceNumber: The packet sequence number.
    ///   - timestamp: The packet timestamp.
    ///   - header: The raw packet header (for decryption).
    ///   - currentTime: Current time in microseconds.
    /// - Returns: Receive result.
    public mutating func processReceivedPacket(
        payload: [UInt8],
        sequenceNumber: SequenceNumber,
        timestamp: UInt32,
        header: [UInt8],
        currentTime: UInt64
    ) throws -> ReceiveResult {
        // Step 1: Decrypt
        var processedPayload = payload
        if let decryptor = decryptor {
            processedPayload = try decryptor.decrypt(
                payload: payload,
                sequenceNumber: sequenceNumber,
                header: header
            )
        }

        // Step 2: Feed to FEC decoder if configured
        fecDecoder?.receiveSourcePacket(
            sequenceNumber: sequenceNumber,
            payload: processedPayload,
            timestamp: timestamp
        )

        // Step 3: Insert into receive buffer
        let packet = ReceiveBuffer.ReceivedPacket(
            sequenceNumber: sequenceNumber,
            payload: processedPayload,
            timestamp: timestamp,
            messageNumber: 0
        )
        let insertResult = receiveBuffer.insert(packet)

        switch insertResult {
        case .duplicate:
            return .duplicate
        case .tooOld:
            return .tooLate
        case .buffered:
            return .buffered
        case .deliverable(let packets):
            return deliverOrQueue(packets: packets, currentTime: currentTime)
        }
    }

    /// Process a received FEC packet.
    ///
    /// - Parameter fecPacket: The received FEC packet.
    /// - Returns: Any packets recovered via FEC.
    public mutating func processReceivedFECPacket(
        _ fecPacket: FECPacket
    ) -> [FECDecoder.RecoveredPacket] {
        guard var decoder = fecDecoder else { return [] }
        decoder.receiveFECPacket(fecPacket)
        let result = decoder.attemptRecovery()
        fecDecoder = decoder

        switch result {
        case .recovered(let packets):
            fecRecoveriesCount += packets.count
            return packets
        case .noLoss, .incomplete, .irrecoverable:
            return []
        }
    }

    /// Check if any buffered packets are ready for delivery.
    ///
    /// - Parameter currentTime: Current time in microseconds.
    /// - Returns: Packets ready for delivery.
    public mutating func pollDelivery(
        currentTime: UInt64
    ) -> [DeliveredPacket] {
        guard !pendingDelivery.isEmpty else { return [] }

        var delivered: [DeliveredPacket] = []
        var remaining: [ReceiveBuffer.ReceivedPacket] = []

        for pkt in pendingDelivery {
            if let tsbpd = tsbpdManager {
                let decision = tsbpd.deliveryDecision(
                    packetTimestamp: pkt.timestamp,
                    currentTime: currentTime,
                    driftCorrection: driftManager.calculateCorrection()
                )
                switch decision {
                case .deliver, .immediate:
                    delivered.append(
                        DeliveredPacket(
                            sequenceNumber: pkt.sequenceNumber,
                            payload: pkt.payload))
                    packetsDeliveredCount += 1
                case .tooLate:
                    _ = tooLateDrop.recordDrop(
                        firstSequence: pkt.sequenceNumber,
                        lastSequence: pkt.sequenceNumber,
                        messageNumber: pkt.messageNumber
                    )
                case .wait:
                    remaining.append(pkt)
                }
            } else {
                delivered.append(
                    DeliveredPacket(
                        sequenceNumber: pkt.sequenceNumber,
                        payload: pkt.payload))
                packetsDeliveredCount += 1
            }
        }

        pendingDelivery = remaining
        return delivered
    }

    // MARK: - Send path

    /// Process an outgoing payload through the full send pipeline.
    ///
    /// Pipeline: reliability (send buffer) → encrypt → FEC → ready for pacing.
    /// - Parameters:
    ///   - payload: The payload to send.
    ///   - currentTime: Current time in microseconds.
    /// - Returns: Send result.
    public mutating func processSend(
        payload: [UInt8],
        currentTime: UInt64
    ) throws -> SendResult {
        let seqNum = nextSequenceNumber
        nextSequenceNumber += 1
        let msgNum = nextMessageNumber
        nextMessageNumber = (nextMessageNumber + 1) & SRTDataPacket.maxMessageNumber

        let timestamp = UInt32(currentTime & 0xFFFF_FFFF)

        // Step 1: Store in send buffer
        let entry = SendBuffer.Entry(
            sequenceNumber: seqNum,
            payload: payload,
            sentTimestamp: currentTime,
            sendCount: 1,
            messageNumber: msgNum
        )
        guard sendBuffer.insert(entry) else {
            nextSequenceNumber -= 1
            nextMessageNumber = msgNum
            return .bufferFull
        }

        // Step 2: Encrypt
        var transmitPayload = payload
        if let encryptor = encryptor {
            transmitPayload = try encryptor.encrypt(
                payload: payload,
                sequenceNumber: seqNum,
                header: []
            )
        }

        // Step 3: Build transmit packet
        var packets: [SRTPacketData] = []
        packets.append(
            SRTPacketData(
                payload: transmitPayload,
                sequenceNumber: seqNum,
                timestamp: timestamp
            ))
        packetsSentCount += 1

        // Step 4: FEC accumulation
        if var encoder = fecEncoder {
            let fecResult = encoder.submitPacket(
                FECEncoder.SourcePacket(
                    sequenceNumber: seqNum,
                    payload: payload,
                    timestamp: timestamp,
                    messageNumber: msgNum
                ))
            if case .fecReady(let fecPkts) = fecResult {
                for fecPkt in fecPkts {
                    packets.append(
                        SRTPacketData(
                            payload: fecPkt.payloadXOR,
                            sequenceNumber: fecPkt.baseSequenceNumber,
                            timestamp: fecPkt.timestampRecovery,
                            isFEC: true
                        ))
                }
            }
            fecEncoder = encoder
        }

        return .transmit(packets: packets)
    }

    // MARK: - Control path

    /// Process an ACK from the peer.
    ///
    /// - Parameters:
    ///   - ackNumber: The acknowledged sequence number.
    ///   - rtt: Round-trip time from peer in microseconds.
    ///   - bandwidth: Estimated bandwidth from peer.
    ///   - availableBuffer: Peer's available buffer size.
    public mutating func processACK(
        ackNumber: SequenceNumber,
        rtt: UInt64,
        bandwidth: UInt64,
        availableBuffer: Int
    ) {
        _ = sendBuffer.acknowledge(upTo: ackNumber)
        rttEstimator.update(rtt: rtt)
        lossDetector.removeLoss(upTo: ackNumber)
    }

    /// Process a NAK from the peer.
    ///
    /// - Parameter lossList: Sequence numbers reported as lost.
    /// - Returns: Packets to retransmit.
    public mutating func processNAK(
        lossList: [SequenceNumber]
    ) -> [SRTPacketData] {
        let requests = retransmissionManager.processNAK(
            lostSequenceNumbers: lossList,
            sendBuffer: &sendBuffer
        )
        retransmissionsCount += requests.count
        return requests.map { req in
            SRTPacketData(
                payload: req.payload,
                sequenceNumber: req.sequenceNumber,
                timestamp: UInt32(req.originalTimestamp & 0xFFFF_FFFF),
                isRetransmit: true
            )
        }
    }

    /// Get pending ACK to send (if any).
    ///
    /// - Parameter currentTime: Current time in microseconds.
    /// - Returns: Reliability action if an ACK is due.
    public mutating func pendingACK(
        currentTime: UInt64
    ) -> ACKManager.ACKAction {
        ackManager.checkPeriodicACK(
            currentTime: currentTime,
            lastAcknowledged: receiveBuffer.lastAcknowledged
        )
    }

    // MARK: - Encryption

    /// Configure encryption with derived keys.
    ///
    /// - Parameters:
    ///   - sek: Session encryption key.
    ///   - salt: Encryption salt.
    ///   - cipherMode: Cipher mode (CTR or GCM).
    ///   - keySize: Key size.
    public mutating func configureEncryption(
        sek: [UInt8],
        salt: [UInt8],
        cipherMode: CipherMode,
        keySize: KeySize
    ) throws {
        self.encryptor = try SRTEncryptor(
            sek: sek, salt: salt, cipherMode: cipherMode, keySize: keySize)
        self.decryptor = try SRTDecryptor(
            sek: sek, salt: salt, cipherMode: cipherMode, keySize: keySize)
    }

    // MARK: - TSBPD setup

    /// Configure TSBPD timing after handshake.
    ///
    /// - Parameters:
    ///   - baseTime: Connection base time in microseconds.
    ///   - firstTimestamp: First packet timestamp.
    public mutating func configureTSBPD(
        baseTime: UInt64,
        firstTimestamp: UInt32
    ) {
        tsbpdManager = TSBPDManager(
            configuration: .init(
                latencyMicroseconds: configuration.latencyMicroseconds),
            baseTime: baseTime,
            firstTimestamp: firstTimestamp
        )
    }

    // MARK: - Stats

    /// Number of packets sent.
    public var packetsSent: Int { packetsSentCount }

    /// Number of packets received and delivered.
    public var packetsDelivered: Int { packetsDeliveredCount }

    /// Number of packets recovered via FEC.
    public var fecRecoveries: Int { fecRecoveriesCount }

    /// Number of retransmissions.
    public var retransmissions: Int { retransmissionsCount }

    /// Current RTT estimate in microseconds.
    public var currentRTT: UInt64 { rttEstimator.smoothedRTT }

    /// Number of packets in the send buffer.
    public var sendBufferCount: Int { sendBuffer.count }

    /// Number of packets in the receive buffer.
    public var receiveBufferCount: Int { receiveBuffer.bufferedCount }

    // MARK: - Private

    /// Decide whether to deliver immediately or queue for TSBPD.
    private mutating func deliverOrQueue(
        packets: [ReceiveBuffer.ReceivedPacket],
        currentTime: UInt64
    ) -> ReceiveResult {
        if tsbpdManager == nil {
            // No TSBPD — deliver immediately
            let delivered = packets.map {
                DeliveredPacket(sequenceNumber: $0.sequenceNumber, payload: $0.payload)
            }
            packetsDeliveredCount += delivered.count
            return .deliver(payloads: delivered)
        }

        // Queue for TSBPD timing
        pendingDelivery.append(contentsOf: packets)

        // Try to deliver any that are ready now
        let ready = pollDelivery(currentTime: currentTime)
        if ready.isEmpty {
            return .buffered
        }
        return .deliver(payloads: ready)
    }
}
