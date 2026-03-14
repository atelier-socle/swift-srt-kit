// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore

/// Core SRT socket actor.
///
/// Integrates all protocol components (transport, handshake,
/// reliability, timing, congestion, encryption, FEC) into a
/// single manageable connection.
///
/// This actor is the owner of all mutable protocol state and
/// drives the connection lifecycle via timed checks.
public actor SRTSocket {
    /// Socket role.
    public enum Role: Sendable {
        /// Initiates connection to a remote listener.
        case caller
        /// Accepts incoming connections.
        case listener
        /// Both sides initiate simultaneously.
        case rendezvous
    }

    /// Socket ID.
    public let socketID: UInt32

    /// Socket role.
    public let role: Role

    /// Current connection state.
    public private(set) var state: SRTConnectionState = .idle

    /// Peer socket ID (set after handshake).
    public private(set) var peerSocketID: UInt32?

    /// Peer address.
    private var peerAddress: SocketAddress?

    /// Packet pipeline for send/receive processing.
    private var pipeline: PacketPipeline

    /// Connection manager for keepalive and shutdown.
    private var connectionManager: ConnectionManager

    /// Congestion controller.
    private var congestionController: any CongestionController

    /// Packet pacer.
    private var pacer: PacketPacer

    /// Event stream continuation.
    private let eventContinuation: AsyncStream<SRTConnectionEvent>.Continuation

    /// Event stream backing storage.
    private let eventStream: AsyncStream<SRTConnectionEvent>

    /// Received data queue for pull-mode receive.
    private var receivedData: [[UInt8]] = []

    /// Pending receive waiters (continuations waiting for data).
    private var receiveWaiters: [CheckedContinuation<[UInt8]?, Never>] = []

    /// Optional UDP channel for wire I/O (nil in unit tests).
    private let channel: UDPChannel?

    /// Microsecond-precision clock.
    private let clock: any SRTClockProtocol

    /// Statistics collector for tracking connection metrics.
    private var statisticsCollector = StatisticsCollector()

    /// Next message number for outgoing data packets (1-based, wraps at 0x03FF_FFFF).
    private var nextMessageNumber: UInt32 = 1

    /// Maximum message number value (26-bit field).
    private static let maxMessageNumber: UInt32 = 0x03FF_FFFF

    /// Create a socket.
    ///
    /// - Parameters:
    ///   - role: Caller, listener, or rendezvous.
    ///   - socketID: Local socket ID.
    ///   - peerAddress: Remote address (for caller).
    ///   - pipelineConfiguration: Pipeline configuration.
    ///   - connectionConfiguration: Connection manager configuration.
    ///   - congestionController: Congestion controller to use.
    ///   - channel: Optional UDP channel for wire I/O.
    ///   - clock: Clock for timestamps (defaults to system clock).
    public init(
        role: Role,
        socketID: UInt32,
        peerAddress: SocketAddress? = nil,
        pipelineConfiguration: PacketPipeline.Configuration = .init(),
        connectionConfiguration: ConnectionManager.Configuration = .init(),
        congestionController: any CongestionController = LiveCC(),
        channel: UDPChannel? = nil,
        clock: any SRTClockProtocol = SystemSRTClock()
    ) {
        self.role = role
        self.socketID = socketID
        self.peerAddress = peerAddress
        self.pipeline = PacketPipeline(configuration: pipelineConfiguration)
        self.connectionManager = ConnectionManager(configuration: connectionConfiguration)
        self.congestionController = congestionController
        self.pacer = PacketPacer()
        self.channel = channel
        self.clock = clock

        let (stream, continuation) = AsyncStream.makeStream(
            of: SRTConnectionEvent.self)
        self.eventStream = stream
        self.eventContinuation = continuation
    }

    /// Connection events stream.
    public var events: AsyncStream<SRTConnectionEvent> { eventStream }

    /// Current connection statistics snapshot.
    ///
    /// - Returns: A snapshot of all collected statistics.
    public func statistics() -> SRTStatistics {
        statisticsCollector.snapshot(at: clock.now())
    }

    /// Send data.
    ///
    /// - Parameter payload: Data to send.
    /// - Returns: Number of bytes queued.
    /// - Throws: If not in active state or buffer full.
    public func send(_ payload: [UInt8]) throws -> Int {
        guard state.isActive else {
            throw SRTConnectionError.invalidState(
                current: state, required: "connected or transferring")
        }
        return try sendInternal(payload)
    }

    /// Receive data.
    ///
    /// Waits until data is available or the connection closes.
    /// - Returns: Next delivered payload, or nil if closed/not connected.
    public func receive() async -> [UInt8]? {
        guard state.isActive else { return nil }
        if !receivedData.isEmpty {
            return receivedData.removeFirst()
        }
        return await withCheckedContinuation { continuation in
            receiveWaiters.append(continuation)
        }
    }

    /// Close the connection gracefully.
    public func close() {
        guard !state.isTerminal else { return }
        let currentTime = clock.now()
        connectionManager.beginShutdown(at: currentTime)
        sendControlToWire(controlType: .shutdown, cif: .shutdown)
        transitionTo(.closing)
    }

    /// Process a raw incoming packet (called by transport/multiplexer).
    ///
    /// - Parameters:
    ///   - data: Raw packet bytes.
    ///   - address: Source address.
    public func handleIncomingPacket(
        _ data: [UInt8],
        from address: SocketAddress
    ) throws {
        connectionManager.peerResponseReceived(at: clock.now())

        // Parse packet using PacketCodec
        var buffer = ByteBuffer(bytes: data)
        let packet = try PacketCodec.decode(from: &buffer)

        switch packet {
        case .data(let dataPacket):
            try handleDataPacket(dataPacket)
        case .control(let controlPacket):
            try handleControlPacket(controlPacket, from: address)
        }
    }

    /// Periodic tick — drives keepalive, ACK, pacing, delivery.
    ///
    /// Called by the connection's timer (every SYN_INTERVAL = 10ms).
    /// - Parameter currentTime: Current time in microseconds.
    public func tick(currentTime: UInt64) throws {
        // Check connection manager
        let action = connectionManager.check(at: currentTime)
        switch action {
        case .sendKeepalive:
            connectionManager.keepaliveSent(at: currentTime)
            sendControlToWire(controlType: .keepalive, cif: .keepalive)
        case .timeout:
            transitionTo(.broken)
            eventContinuation.yield(.keepaliveTimeout)
            eventContinuation.yield(
                .connectionBroken(reason: "Keepalive timeout"))
        case .shutdownComplete:
            transitionTo(.closed)
        case .initiateShutdown, .none:
            break
        }

        // Check pending ACK
        let ackAction = pipeline.pendingACK(currentTime: currentTime)
        switch ackAction {
        case .sendFullACK(let ackSeqNum, let lastACKed):
            statisticsCollector.recordACKSent()
            let ackPacket = ACKPacket(acknowledgementNumber: lastACKed)
            sendControlToWire(
                controlType: .ack,
                typeSpecificInfo: ackSeqNum,
                cif: .ack(ackPacket)
            )
        case .sendLightACK(let lastACKed):
            statisticsCollector.recordACKSent()
            let lightACK = ACKPacket(acknowledgementNumber: lastACKed)
            sendControlToWire(controlType: .ack, cif: .ack(lightACK))
        case .none:
            break
        }

        // Update statistics from pipeline state
        statisticsCollector.updateTiming(
            rttMicroseconds: pipeline.currentRTT,
            rttVarianceMicroseconds: 0
        )
        statisticsCollector.updateBuffers(
            sendBufferPackets: pipeline.sendBufferCount,
            sendBufferCapacity: 8192,
            receiveBufferPackets: pipeline.receiveBufferCount,
            receiveBufferCapacity: 8192,
            flowWindowAvailable: 25600
        )

        // Poll TSBPD delivery
        let delivered = pipeline.pollDelivery(currentTime: currentTime)
        for pkt in delivered {
            deliverPayload(pkt.payload, sequenceNumber: pkt.sequenceNumber)
        }
    }

    // MARK: - State transitions

    /// Transition to a new connection state.
    ///
    /// - Parameter newState: The target state.
    /// - Returns: Whether the transition was valid.
    @discardableResult
    public func transitionTo(_ newState: SRTConnectionState) -> Bool {
        guard state.validTransitions.contains(newState) else { return false }
        let oldState = state
        state = newState
        eventContinuation.yield(.stateChanged(from: oldState, to: newState))
        if newState.isTerminal {
            for waiter in receiveWaiters {
                waiter.resume(returning: nil)
            }
            receiveWaiters.removeAll()
            eventContinuation.finish()
        }
        return true
    }

    // MARK: - Internal

    /// Record that the handshake completed.
    ///
    /// - Parameters:
    ///   - peerSocketID: The peer's socket ID.
    ///   - negotiatedLatency: Negotiated latency in microseconds.
    public func handshakeCompleted(
        peerSocketID: UInt32,
        negotiatedLatency: UInt64
    ) {
        self.peerSocketID = peerSocketID
        eventContinuation.yield(
            .handshakeComplete(
                peerSocketID: peerSocketID,
                negotiatedLatency: negotiatedLatency))
    }

    /// Configure encryption on the packet pipeline.
    ///
    /// - Parameters:
    ///   - sek: Stream Encrypting Key bytes.
    ///   - salt: Encryption salt (16 bytes).
    ///   - cipherMode: CTR or GCM.
    ///   - keySize: Key size.
    public func configureEncryption(
        sek: [UInt8],
        salt: [UInt8],
        cipherMode: CipherMode,
        keySize: KeySize
    ) throws {
        try pipeline.configureEncryption(
            sek: sek, salt: salt, cipherMode: cipherMode, keySize: keySize)
    }

    // MARK: - Private

    /// Deliver a payload to a waiter or the receive queue.
    private func deliverPayload(
        _ payload: [UInt8], sequenceNumber: SequenceNumber
    ) {
        eventContinuation.yield(
            .dataReceived(
                payload: payload, sequenceNumber: sequenceNumber))
        if !receiveWaiters.isEmpty {
            let waiter = receiveWaiters.removeFirst()
            waiter.resume(returning: payload)
        } else {
            receivedData.append(payload)
        }
    }

    /// Send payload through the pipeline.
    private func sendInternal(_ payload: [UInt8]) throws -> Int {
        let currentTime = clock.now()
        let result = try pipeline.processSend(
            payload: payload, currentTime: currentTime)
        switch result {
        case .transmit(let packets):
            for pkt in packets {
                congestionController.onPacketSent(
                    payloadSize: pkt.payload.count,
                    timestamp: pkt.timestamp)
                pacer.packetSent(at: currentTime)
                sendDataPacketToWire(pkt)
            }
            return payload.count
        case .bufferFull:
            throw SRTConnectionError.bufferFull
        }
    }

    /// Handle a received data packet.
    private func handleDataPacket(_ packet: SRTDataPacket) throws {
        statisticsCollector.recordPacketReceived(
            payloadSize: packet.payload.count)

        if state == .connected {
            transitionTo(.transferring)
        }

        let result = try pipeline.processReceivedPacket(
            payload: packet.payload,
            sequenceNumber: packet.sequenceNumber,
            timestamp: packet.timestamp,
            header: [],
            currentTime: clock.now()
        )

        switch result {
        case .deliver(let payloads):
            for pkt in payloads {
                deliverPayload(
                    pkt.payload, sequenceNumber: pkt.sequenceNumber)
            }
        case .buffered:
            break
        case .duplicate:
            statisticsCollector.recordDuplicate()
        case .tooLate:
            statisticsCollector.recordPacketDropped(
                payloadSize: packet.payload.count)
        }
    }

    /// Handle a received control packet.
    private func handleControlPacket(
        _ packet: SRTControlPacket,
        from address: SocketAddress
    ) throws {
        switch packet.controlType {
        case .keepalive:
            break  // peerResponseReceived already called
        case .shutdown:
            transitionTo(.closing)
            transitionTo(.closed)
        case .ack:
            handleACK(packet)
        case .nak:
            statisticsCollector.recordPacketLost()
        default:
            break
        }
    }

    /// Process an incoming ACK: update send buffer and respond with ACKACK.
    private func handleACK(_ packet: SRTControlPacket) {
        var cifBuffer = ByteBuffer(bytes: packet.controlInfoField)
        if let ack = try? ACKPacket.decode(from: &cifBuffer, cifLength: packet.controlInfoField.count) {
            pipeline.processACK(
                ackNumber: ack.acknowledgementNumber,
                rtt: UInt64(ack.rtt ?? 0),
                bandwidth: UInt64(ack.estimatedLinkCapacity ?? 0),
                availableBuffer: Int(ack.availableBufferSize ?? 8192)
            )
        }
        sendControlToWire(controlType: .ackack, typeSpecificInfo: packet.typeSpecificInfo, cif: .ackack)
    }

    /// Encode and send a data packet to the wire via the channel.
    private func sendDataPacketToWire(_ pkt: PacketPipeline.SRTPacketData) {
        statisticsCollector.recordPacketSent(payloadSize: pkt.payload.count)
        guard let channel else { return }
        let destID = peerSocketID ?? 0
        let dataPacket = SRTDataPacket(
            sequenceNumber: pkt.sequenceNumber,
            position: .single,
            orderFlag: false,
            encryptionKey: pipeline.isEncryptionActive ? .even : .none,
            retransmitted: pkt.isRetransmit,
            messageNumber: nextMessageNumber,
            timestamp: pkt.timestamp,
            destinationSocketID: destID,
            payload: pkt.payload
        )

        nextMessageNumber = nextMessageNumber >= Self.maxMessageNumber ? 1 : nextMessageNumber + 1
        var buffer = ByteBuffer()
        PacketCodec.encode(.data(dataPacket), into: &buffer)
        Task { try? await channel.send(buffer) }
    }

    /// Encode and send a control packet to the wire via the channel.
    private func sendControlToWire(
        controlType: ControlType,
        typeSpecificInfo: UInt32 = 0,
        cif: ControlInfoField
    ) {
        guard let channel else { return }
        let destID = peerSocketID ?? 0
        var buffer = ByteBuffer()
        PacketCodec.encode(
            controlType: controlType,
            typeSpecificInfo: typeSpecificInfo,
            timestamp: UInt32(truncatingIfNeeded: clock.now()),
            destinationSocketID: destID,
            cif: cif,
            into: &buffer
        )
        Task { try? await channel.send(buffer) }
    }
}
