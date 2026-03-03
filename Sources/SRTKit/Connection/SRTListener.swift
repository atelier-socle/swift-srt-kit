// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore

/// Listener-mode SRT server.
///
/// Binds to a local port and accepts incoming SRT connections.
/// Each accepted connection is an independent SRTSocket.
public actor SRTListener {
    /// Listener configuration.
    public struct Configuration: Sendable {
        /// Local host to bind to.
        public let host: String
        /// Local port to bind to.
        public let port: Int
        /// Maximum pending connections.
        public let backlog: Int
        /// Encryption passphrase (nil = no encryption required).
        public let passphrase: String?
        /// Encryption key size.
        public let keySize: KeySize
        /// Cipher mode.
        public let cipherMode: CipherMode
        /// Latency in microseconds.
        public let latency: UInt64

        /// Creates a listener configuration.
        ///
        /// - Parameters:
        ///   - host: Local host to bind to.
        ///   - port: Local port to bind to.
        ///   - backlog: Maximum pending connections.
        ///   - passphrase: Encryption passphrase.
        ///   - keySize: Encryption key size.
        ///   - cipherMode: Cipher mode.
        ///   - latency: Latency in microseconds.
        public init(
            host: String = "0.0.0.0",
            port: Int,
            backlog: Int = 5,
            passphrase: String? = nil,
            keySize: KeySize = .aes128,
            cipherMode: CipherMode = .ctr,
            latency: UInt64 = 120_000
        ) {
            self.host = host
            self.port = port
            self.backlog = backlog
            self.passphrase = passphrase
            self.keySize = keySize
            self.cipherMode = cipherMode
            self.latency = latency
        }
    }

    /// The listener configuration.
    public let configuration: Configuration

    /// Whether the listener is running.
    public private(set) var isListening: Bool = false

    /// Number of currently active connections.
    public private(set) var activeConnectionCount: Int = 0

    /// The actual bound port (useful when binding to port 0).
    public private(set) var boundPort: Int?

    /// Active connections by socket ID.
    private var activeConnections: [UInt32: SRTSocket] = [:]

    /// Incoming connections stream continuation.
    private var connectionContinuation: AsyncStream<SRTSocket>.Continuation?

    /// Incoming connections stream backing storage.
    private var connectionStream: AsyncStream<SRTSocket>?

    /// UDP transport for wire I/O.
    private var transport: UDPTransport?

    /// Packet multiplexer.
    private var multiplexer: Multiplexer?

    /// Handshake dispatch task.
    private var handshakeTask: Task<Void, Never>?

    /// Random cookie secret (32 bytes, generated at init).
    private let cookieSecret: [UInt8]

    /// Clock for timestamps.
    private let clock: any SRTClockProtocol

    /// Creates a listener.
    ///
    /// - Parameter configuration: The listener configuration.
    public init(configuration: Configuration) {
        self.configuration = configuration
        var secret = [UInt8](repeating: 0, count: 32)
        for i in 0..<32 {
            secret[i] = UInt8.random(in: 0...255)
        }
        self.cookieSecret = secret
        self.clock = SystemSRTClock()
    }

    /// Stream of accepted connections.
    public var incomingConnections: AsyncStream<SRTSocket> {
        if let stream = connectionStream {
            return stream
        }
        let (stream, continuation) = AsyncStream.makeStream(
            of: SRTSocket.self)
        self.connectionContinuation = continuation
        self.connectionStream = stream
        return stream
    }

    /// Start listening for connections.
    ///
    /// Binds to the configured port and begins accepting handshakes.
    /// - Throws: If already listening or bind fails.
    public func start() async throws {
        guard !isListening else {
            throw SRTConnectionError.alreadyListening
        }

        if connectionStream == nil {
            let (stream, continuation) = AsyncStream.makeStream(
                of: SRTSocket.self)
            self.connectionContinuation = continuation
            self.connectionStream = stream
        }

        let transportConfig = UDPTransport.Configuration(
            host: configuration.host,
            port: configuration.port
        )
        let udpTransport = UDPTransport(configuration: transportConfig)
        let localAddr = try await udpTransport.bind()
        self.transport = udpTransport
        self.boundPort = localAddr.port

        let mux = Multiplexer()
        self.multiplexer = mux

        isListening = true

        let incomingDatagrams = await udpTransport.incomingDatagrams
        self.handshakeTask = Task { [weak self] in
            for await datagram in incomingDatagrams {
                guard let self else { break }
                await self.handleIncomingDatagram(datagram)
            }
        }
    }

    /// Stop the listener and close all connections.
    public func stop() async {
        isListening = false

        handshakeTask?.cancel()
        handshakeTask = nil

        for (_, socket) in activeConnections {
            await socket.close()
        }
        activeConnections.removeAll()
        activeConnectionCount = 0

        if let transport {
            try? await transport.close()
        }
        self.transport = nil
        self.multiplexer = nil
        self.boundPort = nil

        connectionContinuation?.finish()
        connectionContinuation = nil
        connectionStream = nil
    }

    /// Accept a new connection (called internally when handshake completes).
    ///
    /// - Parameter socket: The accepted socket.
    internal func acceptConnection(_ socket: SRTSocket) {
        let id = socket.socketID
        activeConnections[id] = socket
        activeConnectionCount = activeConnections.count
        connectionContinuation?.yield(socket)
    }

    /// Remove a closed connection.
    ///
    /// - Parameter socketID: The socket ID to remove.
    internal func removeConnection(socketID: UInt32) {
        activeConnections.removeValue(forKey: socketID)
        activeConnectionCount = activeConnections.count
    }
}

// MARK: - Private Datagram Handling

extension SRTListener {

    /// Handle an incoming datagram — dispatch to multiplexer or handshake.
    private func handleIncomingDatagram(
        _ datagram: IncomingDatagram
    ) async {
        let buf = datagram.data
        guard buf.readableBytes >= PacketCodec.minimumHeaderSize else {
            return
        }

        let destSocketID =
            buf.getInteger(
                at: buf.readerIndex + 12, as: UInt32.self) ?? 0

        if destSocketID != 0 {
            if let mux = multiplexer,
                await mux.hasRegistration(for: destSocketID)
            {
                await mux.dispatch(datagram)
                return
            }
            // Not registered — likely a handshake conclusion
        }

        await handleHandshakeDatagram(datagram)
    }

    /// Handle a handshake datagram (induction or conclusion).
    private func handleHandshakeDatagram(
        _ datagram: IncomingDatagram
    ) async {
        guard let decoded = try? Self.decodeHandshakeDatagram(datagram)
        else {
            return
        }

        let hsConfig = buildHandshakeConfig()
        let peerPort = Self.portFromSocketAddress(datagram.remoteAddress)

        switch decoded.packet.handshakeType {
        case .waveahand, .induction:
            await handleInduction(
                decoded: decoded, datagram: datagram,
                hsConfig: hsConfig, peerPort: peerPort)

        case .conclusion:
            await handleConclusion(
                decoded: decoded, datagram: datagram,
                hsConfig: hsConfig, peerPort: peerPort)

        default:
            break
        }
    }

    /// Handle induction phase — stateless response.
    private func handleInduction(
        decoded: DecodedHandshake,
        datagram: IncomingDatagram,
        hsConfig: HandshakeConfiguration,
        peerPort: UInt16
    ) async {
        let hs = ListenerHandshake(configuration: hsConfig)
        let action = hs.processInduction(
            handshake: decoded.packet,
            from: decoded.peerAddress,
            cookieSecret: cookieSecret,
            peerPort: peerPort,
            timeBucket: Self.currentTimeBucket()
        )
        if case .sendPacket(let pkt, let exts) = action {
            await sendHandshakeResponse(
                pkt, extensions: exts,
                to: datagram.remoteAddress,
                destinationSocketID: decoded.packet.srtSocketID
            )
        }
    }

    /// Handle conclusion phase — create connection.
    private func handleConclusion(
        decoded: DecodedHandshake,
        datagram: IncomingDatagram,
        hsConfig: HandshakeConfiguration,
        peerPort: UInt16
    ) async {
        var hs = ListenerHandshake(configuration: hsConfig)
        let actions = hs.processConclusion(
            handshake: decoded.packet,
            extensions: decoded.extensions,
            from: decoded.peerAddress,
            cookieSecret: cookieSecret,
            peerPort: peerPort,
            timeBucket: Self.currentTimeBucket()
        )

        var handshakeResult: HandshakeResult?
        for action in actions {
            switch action {
            case .sendPacket(let pkt, let exts):
                await sendHandshakeResponse(
                    pkt, extensions: exts,
                    to: datagram.remoteAddress,
                    destinationSocketID: decoded.packet.srtSocketID
                )
            case .completed(let result):
                handshakeResult = result
            case .error:
                return
            case .waitForResponse:
                break
            }
        }

        if let result = handshakeResult {
            await createAcceptedSocket(
                result: result,
                localSocketID: hsConfig.localSocketID,
                remoteAddress: datagram.remoteAddress
            )
        }
    }

    /// Build a handshake configuration from listener settings.
    private func buildHandshakeConfig() -> HandshakeConfiguration {
        let cipherType: UInt16 =
            configuration.passphrase != nil
            ? (configuration.cipherMode == .gcm ? 3 : 2)
            : 0
        let latencyMs = UInt16(configuration.latency / 1000)
        return HandshakeConfiguration(
            localSocketID: UInt32.random(in: 1...UInt32.max),
            senderTSBPDDelay: latencyMs,
            receiverTSBPDDelay: latencyMs,
            passphrase: configuration.passphrase,
            cipherType: cipherType
        )
    }

    /// Create a socket from a completed handshake and register it.
    private func createAcceptedSocket(
        result: HandshakeResult,
        localSocketID: UInt32,
        remoteAddress: SocketAddress
    ) async {
        guard let transport, let multiplexer else { return }

        let socketID = localSocketID
        let negotiatedLatency =
            UInt64(
                max(result.senderTSBPDDelay, result.receiverTSBPDDelay))
            * 1000

        let udpChannel = UDPChannel(
            socketID: socketID,
            transport: transport,
            multiplexer: multiplexer,
            remoteAddress: remoteAddress
        )
        let channelStream = await udpChannel.open()

        let pipelineConfig = PacketPipeline.Configuration(
            latencyMicroseconds: negotiatedLatency,
            initialSequenceNumber: result.initialSequenceNumber
        )
        let socket = SRTSocket(
            role: .listener,
            socketID: socketID,
            pipelineConfiguration: pipelineConfig,
            channel: udpChannel,
            clock: clock
        )
        await socket.handshakeCompleted(
            peerSocketID: result.peerSocketID,
            negotiatedLatency: negotiatedLatency
        )

        // Configure encryption if key material was negotiated
        if let sek = result.encryptionSEK, let salt = result.encryptionSalt {
            try? await socket.configureEncryption(
                sek: sek, salt: salt,
                cipherMode: configuration.cipherMode,
                keySize: configuration.keySize)
        }

        await socket.transitionTo(.connecting)
        await socket.transitionTo(.handshaking)
        await socket.transitionTo(.connected)

        startSocketTasks(
            socket: socket, socketID: socketID,
            channelStream: channelStream)

        acceptConnection(socket)
    }

    /// Start tick and receive forwarding tasks for an accepted socket.
    private func startSocketTasks(
        socket: SRTSocket,
        socketID: UInt32,
        channelStream: AsyncStream<IncomingDatagram>
    ) {
        Task { [weak self, clock] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(10))
                let time = clock.now()
                guard let self else { break }
                let sock = await self.activeConnections[socketID]
                guard let sock else { break }
                try? await sock.tick(currentTime: time)
            }
        }

        Task { [socket] in
            for await datagram in channelStream {
                let buf = datagram.data
                guard buf.readableBytes >= PacketCodec.minimumHeaderSize
                else { continue }
                let bytes = Array(buf.readableBytesView)
                try? await socket.handleIncomingPacket(
                    bytes, from: datagram.remoteAddress)
            }
        }
    }

    /// Send a handshake response via the transport.
    private func sendHandshakeResponse(
        _ packet: HandshakePacket,
        extensions: [HandshakeExtensionData],
        to remoteAddress: SocketAddress,
        destinationSocketID: UInt32
    ) async {
        guard let transport else { return }
        let buffer = HandshakePacketEncoder.encode(
            handshake: packet,
            extensions: extensions,
            destinationSocketID: destinationSocketID,
            timestamp: UInt32(truncatingIfNeeded: clock.now())
        )
        try? await transport.send(buffer, to: remoteAddress)
    }
}

// MARK: - Private Static Helpers

extension SRTListener {

    /// Decoded handshake datagram components.
    private struct DecodedHandshake: Sendable {
        let packet: HandshakePacket
        let extensions: [HandshakeExtensionData]
        let peerAddress: SRTPeerAddress
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
            return .ipv4(0x7F00_0001)
        case .unixDomainSocket:
            return .ipv4(0x7F00_0001)
        }
    }

    /// Extract the port number from a SocketAddress.
    private static func portFromSocketAddress(
        _ address: SocketAddress
    ) -> UInt16 {
        UInt16(address.port ?? 0)
    }

    /// Get current time bucket for cookie generation (60-second windows).
    private static func currentTimeBucket() -> UInt32 {
        let clock = SystemSRTClock()
        return UInt32(clock.now() / 60_000_000)
    }
}
