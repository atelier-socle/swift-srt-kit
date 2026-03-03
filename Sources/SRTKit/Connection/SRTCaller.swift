// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore

/// Caller-mode SRT connection.
///
/// Initiates a connection to a remote SRT listener,
/// performs handshake, then enables bidirectional data transfer.
public actor SRTCaller {
    /// Caller configuration.
    public struct Configuration: Sendable {
        /// Remote host.
        public let host: String
        /// Remote port.
        public let port: Int
        /// Connection timeout in microseconds.
        public let connectTimeout: UInt64
        /// StreamID for access control.
        public let streamID: String?
        /// Encryption passphrase (nil = no encryption).
        public let passphrase: String?
        /// Encryption key size.
        public let keySize: KeySize
        /// Cipher mode.
        public let cipherMode: CipherMode
        /// Latency in microseconds.
        public let latency: UInt64
        /// Congestion controller name ("live" or "file").
        public let congestionControl: String
        /// FEC configuration (nil = no FEC).
        public let fecConfiguration: FECConfiguration?

        /// Creates a caller configuration.
        ///
        /// - Parameters:
        ///   - host: Remote host.
        ///   - port: Remote port.
        ///   - connectTimeout: Connection timeout in microseconds.
        ///   - streamID: StreamID for access control.
        ///   - passphrase: Encryption passphrase.
        ///   - keySize: Encryption key size.
        ///   - cipherMode: Cipher mode.
        ///   - latency: Latency in microseconds.
        ///   - congestionControl: Congestion controller name.
        ///   - fecConfiguration: FEC configuration.
        public init(
            host: String,
            port: Int,
            connectTimeout: UInt64 = 3_000_000,
            streamID: String? = nil,
            passphrase: String? = nil,
            keySize: KeySize = .aes128,
            cipherMode: CipherMode = .ctr,
            latency: UInt64 = 120_000,
            congestionControl: String = "live",
            fecConfiguration: FECConfiguration? = nil
        ) {
            self.host = host
            self.port = port
            self.connectTimeout = connectTimeout
            self.streamID = streamID
            self.passphrase = passphrase
            self.keySize = keySize
            self.cipherMode = cipherMode
            self.latency = latency
            self.congestionControl = congestionControl
            self.fecConfiguration = fecConfiguration
        }
    }

    /// The caller configuration.
    public let configuration: Configuration

    /// The underlying socket.
    private var socket: SRTSocket?

    /// Current connection state.
    public private(set) var state: SRTConnectionState = .idle

    /// Whether a connect attempt is in progress.
    private var connectInProgress: Bool = false

    /// Event stream continuation.
    private let eventContinuation: AsyncStream<SRTConnectionEvent>.Continuation

    /// Event stream backing storage.
    private let eventStream: AsyncStream<SRTConnectionEvent>

    /// UDP transport for wire I/O.
    private var transport: UDPTransport?

    /// Packet multiplexer.
    private var multiplexer: Multiplexer?

    /// Per-connection UDP channel.
    private var channel: UDPChannel?

    /// Periodic tick task.
    private var tickTask: Task<Void, Never>?

    /// Incoming packet forwarding task.
    private var receiveTask: Task<Void, Never>?

    /// Transport dispatch task.
    private var dispatchTask: Task<Void, Never>?

    /// Clock for timestamps.
    private let clock: any SRTClockProtocol

    /// Creates a caller.
    ///
    /// - Parameter configuration: The caller configuration.
    public init(configuration: Configuration) {
        self.configuration = configuration
        self.clock = SystemSRTClock()

        let (stream, continuation) = AsyncStream.makeStream(
            of: SRTConnectionEvent.self)
        self.eventStream = stream
        self.eventContinuation = continuation
    }

    /// Event stream.
    public var events: AsyncStream<SRTConnectionEvent> { eventStream }

    /// Current connection statistics snapshot.
    ///
    /// - Returns: Statistics from the underlying socket, or empty if not connected.
    public func statistics() async -> SRTStatistics {
        guard let socket else { return SRTStatistics() }
        return await socket.statistics()
    }

    /// Connect to the remote listener.
    ///
    /// Performs full handshake (induction + conclusion) over real UDP I/O.
    /// - Throws: On connection failure, timeout, or rejection.
    public func connect() async throws {
        guard state == .idle else {
            throw SRTConnectionError.invalidState(
                current: state, required: "idle")
        }
        guard !connectInProgress else {
            throw SRTConnectionError.invalidState(
                current: state, required: "idle (not already connecting)")
        }

        connectInProgress = true
        state = .connecting
        eventContinuation.yield(.stateChanged(from: .idle, to: .connecting))

        let remoteAddress = try AddressResolver.resolve(
            host: configuration.host, port: configuration.port)
        let setup = try await setupTransport(remoteAddress: remoteAddress)

        state = .handshaking
        eventContinuation.yield(
            .stateChanged(from: .connecting, to: .handshaking))

        let result = try await performHandshake(
            socketID: setup.socketID, channel: setup.channel,
            channelStream: setup.channelStream)

        await finalizeConnection(
            result: result, socketID: setup.socketID,
            channel: setup.channel, transport: setup.transport)
    }

    /// Send data.
    ///
    /// - Parameter payload: Data to send.
    /// - Returns: Number of bytes queued.
    /// - Throws: If not in active state.
    public func send(_ payload: [UInt8]) async throws -> Int {
        guard state.isActive else {
            throw SRTConnectionError.invalidState(
                current: state, required: "connected or transferring")
        }
        guard let socket = socket else {
            throw SRTConnectionError.invalidState(
                current: state, required: "connected with socket")
        }
        return try await socket.send(payload)
    }

    /// Receive data.
    ///
    /// - Returns: Next delivered payload, or nil if closed.
    public func receive() async -> [UInt8]? {
        guard let socket = socket else { return nil }
        return await socket.receive()
    }

    /// Disconnect gracefully.
    public func disconnect() async {
        guard !state.isTerminal else { return }
        let oldState = state
        state = .closing
        eventContinuation.yield(.stateChanged(from: oldState, to: .closing))

        tickTask?.cancel()
        receiveTask?.cancel()
        dispatchTask?.cancel()
        tickTask = nil
        receiveTask = nil
        dispatchTask = nil

        if let socket = socket {
            await socket.close()
        }
        if let channel {
            await channel.close()
        }
        if let transport {
            try? await transport.close()
        }

        state = .closed
        eventContinuation.yield(.stateChanged(from: .closing, to: .closed))
        eventContinuation.finish()
        connectInProgress = false
    }

    /// Complete the handshake (called internally for testing).
    ///
    /// - Parameters:
    ///   - socket: The connected socket.
    ///   - peerSocketID: The peer's socket ID.
    ///   - negotiatedLatency: Negotiated latency in microseconds.
    internal func completeHandshake(
        socket: SRTSocket,
        peerSocketID: UInt32,
        negotiatedLatency: UInt64
    ) {
        self.socket = socket
        state = .connected
        eventContinuation.yield(
            .stateChanged(from: .handshaking, to: .connected))
        eventContinuation.yield(
            .handshakeComplete(
                peerSocketID: peerSocketID,
                negotiatedLatency: negotiatedLatency))
    }
}

// MARK: - Private Connect Helpers

extension SRTCaller {

    /// Result of transport setup.
    private struct TransportSetup {
        let transport: UDPTransport
        let channel: UDPChannel
        let channelStream: AsyncStream<IncomingDatagram>
        let socketID: UInt32
    }

    /// Create transport, multiplexer, and channel for the connection.
    private func setupTransport(
        remoteAddress: SocketAddress
    ) async throws -> TransportSetup {
        let transportConfig = UDPTransport.Configuration(
            host: "0.0.0.0", port: 0)
        let udpTransport = UDPTransport(configuration: transportConfig)
        _ = try await udpTransport.bind()
        self.transport = udpTransport

        let mux = Multiplexer()
        self.multiplexer = mux

        let socketID = UInt32.random(in: 1...UInt32.max)
        let udpChannel = UDPChannel(
            socketID: socketID,
            transport: udpTransport,
            multiplexer: mux,
            remoteAddress: remoteAddress
        )
        let channelStream = await udpChannel.open()
        self.channel = udpChannel

        let incomingDatagrams = await udpTransport.incomingDatagrams
        self.dispatchTask = Task { [weak mux] in
            guard let mux else { return }
            for await datagram in incomingDatagrams {
                await mux.dispatch(datagram)
            }
        }

        return TransportSetup(
            transport: udpTransport, channel: udpChannel,
            channelStream: channelStream, socketID: socketID)
    }

    /// Run the handshake protocol with timeout.
    private func performHandshake(
        socketID: UInt32,
        channel: UDPChannel,
        channelStream: AsyncStream<IncomingDatagram>
    ) async throws -> HandshakeResult {
        let hsConfig = Self.buildHandshakeConfig(
            socketID: socketID, configuration: configuration)
        let handshake = CallerHandshake(configuration: hsConfig)
        let timeoutUs = configuration.connectTimeout
        let hsClock = self.clock

        return try await withThrowingTaskGroup(
            of: HandshakeResult.self
        ) { group in
            group.addTask {
                try await Task.sleep(for: .microseconds(timeoutUs))
                throw SRTConnectionError.connectionTimeout
            }
            group.addTask { [handshake, channel, channelStream] in
                try await Self.runHandshakeLoop(
                    handshake: handshake, channel: channel,
                    channelStream: channelStream, clock: hsClock)
            }
            guard let result = try await group.next() else {
                throw SRTConnectionError.connectionTimeout
            }
            group.cancelAll()
            return result
        }
    }

    /// Set up the connected socket and start background tasks.
    private func finalizeConnection(
        result: HandshakeResult,
        socketID: UInt32,
        channel: UDPChannel,
        transport: UDPTransport
    ) async {
        let negotiatedLatency =
            UInt64(
                max(result.senderTSBPDDelay, result.receiverTSBPDDelay))
            * 1000
        let pipelineConfig = PacketPipeline.Configuration(
            latencyMicroseconds: negotiatedLatency,
            initialSequenceNumber: result.initialSequenceNumber
        )
        let srtSocket = SRTSocket(
            role: .caller,
            socketID: socketID,
            pipelineConfiguration: pipelineConfig,
            channel: channel,
            clock: clock
        )
        await srtSocket.handshakeCompleted(
            peerSocketID: result.peerSocketID,
            negotiatedLatency: negotiatedLatency
        )
        await srtSocket.transitionTo(.connecting)
        await srtSocket.transitionTo(.handshaking)
        await srtSocket.transitionTo(.connected)
        self.socket = srtSocket

        startTickTask()
        await startReceiveTask(transport: transport)

        state = .connected
        eventContinuation.yield(
            .stateChanged(from: .handshaking, to: .connected))
        eventContinuation.yield(
            .handshakeComplete(
                peerSocketID: result.peerSocketID,
                negotiatedLatency: negotiatedLatency))
    }

    /// Start the periodic tick timer.
    private func startTickTask() {
        self.tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(10))
                guard let self else { break }
                let time = self.clock.now()
                guard let sock = await self.socket else { break }
                try? await sock.tick(currentTime: time)
            }
        }
    }

    /// Start the receive forwarding task.
    private func startReceiveTask(transport: UDPTransport) async {
        let channelForReceive = await transport.incomingDatagrams
        self.receiveTask = Task { [weak self] in
            for await datagram in channelForReceive {
                guard let self else { break }
                guard let sock = await self.socket else { break }
                let buf = datagram.data
                guard buf.readableBytes >= PacketCodec.minimumHeaderSize
                else {
                    continue
                }
                let destID =
                    buf.getInteger(
                        at: buf.readerIndex + 12, as: UInt32.self) ?? 0
                guard destID != 0 else { continue }
                let bytes = Array(buf.readableBytesView)
                try? await sock.handleIncomingPacket(
                    bytes, from: datagram.remoteAddress)
            }
        }
    }
}

// MARK: - Private Static Handshake Helpers

extension SRTCaller {

    /// Decoded handshake datagram components.
    private struct DecodedHandshake: Sendable {
        let packet: HandshakePacket
        let extensions: [HandshakeExtensionData]
        let peerAddress: SRTPeerAddress
    }

    /// Build a handshake configuration from caller settings.
    private static func buildHandshakeConfig(
        socketID: UInt32,
        configuration: Configuration
    ) -> HandshakeConfiguration {
        let latencyMs = UInt16(configuration.latency / 1000)
        let cipherType: UInt16 =
            configuration.passphrase != nil
            ? (configuration.cipherMode == .gcm ? 3 : 2)
            : 0
        return HandshakeConfiguration(
            localSocketID: socketID,
            senderTSBPDDelay: latencyMs,
            receiverTSBPDDelay: latencyMs,
            streamID: configuration.streamID,
            passphrase: configuration.passphrase,
            cipherType: cipherType
        )
    }

    /// Execute the handshake state machine loop.
    private static func runHandshakeLoop(
        handshake: CallerHandshake,
        channel: UDPChannel,
        channelStream: AsyncStream<IncomingDatagram>,
        clock: any SRTClockProtocol
    ) async throws -> HandshakeResult {
        var hs = handshake
        let actions = hs.start()
        try await processHandshakeActions(
            actions, channel: channel, peerSocketID: 0, clock: clock)

        for await datagram in channelStream {
            let decoded = try decodeHandshakeDatagram(datagram)
            let responseActions = hs.receive(
                handshake: decoded.packet,
                extensions: decoded.extensions,
                from: decoded.peerAddress
            )
            for action in responseActions {
                switch action {
                case .completed(let result):
                    return result
                case .sendPacket(let pkt, let exts):
                    // HSv5: CONCLUSION destSocketID must be 0.
                    // The listener routes by SYN cookie, not destSocketID.
                    try await sendHandshakePacket(
                        pkt, extensions: exts,
                        channel: channel,
                        destinationSocketID: 0,
                        clock: clock
                    )
                case .error(let error):
                    throw error
                case .waitForResponse:
                    continue
                }
            }
        }
        throw SRTConnectionError.connectionTimeout
    }

    /// Process handshake actions from the state machine.
    private static func processHandshakeActions(
        _ actions: [HandshakeAction],
        channel: UDPChannel,
        peerSocketID: UInt32,
        clock: any SRTClockProtocol
    ) async throws {
        for action in actions {
            switch action {
            case .sendPacket(let pkt, let exts):
                try await sendHandshakePacket(
                    pkt, extensions: exts,
                    channel: channel,
                    destinationSocketID: peerSocketID,
                    clock: clock
                )
            case .error(let error):
                throw error
            case .completed, .waitForResponse:
                break
            }
        }
    }

    /// Send a handshake packet via the channel.
    private static func sendHandshakePacket(
        _ packet: HandshakePacket,
        extensions: [HandshakeExtensionData],
        channel: UDPChannel,
        destinationSocketID: UInt32,
        clock: any SRTClockProtocol
    ) async throws {
        let buffer = HandshakePacketEncoder.encode(
            handshake: packet,
            extensions: extensions,
            destinationSocketID: destinationSocketID,
            timestamp: UInt32(truncatingIfNeeded: clock.now())
        )
        try await channel.send(buffer)
    }

    /// Decode a raw datagram into handshake components.
    private static func decodeHandshakeDatagram(
        _ datagram: IncomingDatagram
    ) throws -> DecodedHandshake {
        var buffer = datagram.data
        let srtPacket = try PacketCodec.decode(from: &buffer)
        guard case .control(let control) = srtPacket,
            control.controlType == .handshake
        else {
            throw SRTError.handshakeFailed("Expected handshake packet")
        }

        var cifBuffer = ByteBuffer(bytes: control.controlInfoField)
        let hsPacket = try HandshakePacket.decode(from: &cifBuffer)
        let extensions = try HandshakePacketEncoder.decodeExtensions(
            from: &cifBuffer)

        let peerAddress = peerAddressFromSocketAddress(
            datagram.remoteAddress)

        return DecodedHandshake(
            packet: hsPacket,
            extensions: extensions,
            peerAddress: peerAddress
        )
    }

    /// Convert a NIO SocketAddress to an SRTPeerAddress.
    private static func peerAddressFromSocketAddress(
        _ address: SocketAddress
    ) -> SRTPeerAddress {
        switch address {
        case .v4(let addr):
            let ip = addr.address.sin_addr.s_addr
            let hostOrder = UInt32(bigEndian: ip)
            return .ipv4(hostOrder)
        case .v6:
            return .ipv4(0x7F00_0001)  // fallback to 127.0.0.1
        case .unixDomainSocket:
            return .ipv4(0x7F00_0001)
        }
    }
}
