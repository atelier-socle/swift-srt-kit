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

    /// Optional UDP channel for wire I/O (nil in unit tests).
    private let channel: UDPChannel?

    /// Microsecond-precision clock.
    private let clock: any SRTClockProtocol

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

    /// Receive data (pull mode).
    ///
    /// - Returns: Next delivered payload, or nil if closed.
    public func receive() async -> [UInt8]? {
        guard !state.isTerminal else { return nil }
        if !receivedData.isEmpty {
            return receivedData.removeFirst()
        }
        return nil
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
            let ackPacket = ACKPacket(acknowledgementNumber: lastACKed)
            sendControlToWire(
                controlType: .ack,
                typeSpecificInfo: ackSeqNum,
                cif: .ack(ackPacket)
            )
        case .sendLightACK(let lastACKed):
            let lightACK = ACKPacket(acknowledgementNumber: lastACKed)
            sendControlToWire(controlType: .ack, cif: .ack(lightACK))
        case .none:
            break
        }

        // Poll TSBPD delivery
        let delivered = pipeline.pollDelivery(currentTime: currentTime)
        for pkt in delivered {
            receivedData.append(pkt.payload)
            eventContinuation.yield(
                .dataReceived(
                    payload: pkt.payload,
                    sequenceNumber: pkt.sequenceNumber))
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

    // MARK: - Private

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
                receivedData.append(pkt.payload)
                eventContinuation.yield(
                    .dataReceived(
                        payload: pkt.payload,
                        sequenceNumber: pkt.sequenceNumber))
            }
        case .buffered, .duplicate, .tooLate:
            break
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
            break  // Would parse ACK CIF and call pipeline.processACK
        case .nak:
            break  // Would parse NAK CIF and call pipeline.processNAK
        default:
            break
        }
    }

    /// Encode and send a data packet to the wire via the channel.
    private func sendDataPacketToWire(_ pkt: PacketPipeline.SRTPacketData) {
        guard let channel else { return }
        let destID = peerSocketID ?? 0
        let dataPacket = SRTDataPacket(
            sequenceNumber: pkt.sequenceNumber,
            position: .single,
            orderFlag: false,
            encryptionKey: .none,
            retransmitted: pkt.isRetransmit,
            messageNumber: 0,
            timestamp: pkt.timestamp,
            destinationSocketID: destID,
            payload: pkt.payload
        )
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
