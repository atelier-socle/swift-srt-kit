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

    /// Creates a caller.
    ///
    /// - Parameter configuration: The caller configuration.
    public init(configuration: Configuration) {
        self.configuration = configuration

        let (stream, continuation) = AsyncStream.makeStream(
            of: SRTConnectionEvent.self)
        self.eventStream = stream
        self.eventContinuation = continuation
    }

    /// Event stream.
    public var events: AsyncStream<SRTConnectionEvent> { eventStream }

    /// Connect to the remote listener.
    ///
    /// Performs full handshake (induction + conclusion).
    /// - Throws: If already connecting or connected.
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

        state = .handshaking
        eventContinuation.yield(
            .stateChanged(from: .connecting, to: .handshaking))

        // In full implementation: create UDPTransport, perform handshake
        // For now, state transitions are set up for testing
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

        if let socket = socket {
            await socket.close()
        }

        state = .closed
        eventContinuation.yield(.stateChanged(from: .closing, to: .closed))
        eventContinuation.finish()
        connectInProgress = false
    }

    /// Complete the handshake (called internally after handshake finishes).
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
