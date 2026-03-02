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

    /// Active connections by socket ID.
    private var activeConnections: [UInt32: SRTSocket] = [:]

    /// Incoming connections stream continuation.
    private var connectionContinuation: AsyncStream<SRTSocket>.Continuation?

    /// Incoming connections stream backing storage.
    private var connectionStream: AsyncStream<SRTSocket>?

    /// Creates a listener.
    ///
    /// - Parameter configuration: The listener configuration.
    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    /// Stream of accepted connections.
    public var incomingConnections: AsyncStream<SRTSocket> {
        if let stream = connectionStream {
            return stream
        }
        let (stream, continuation) = AsyncStream.makeStream(of: SRTSocket.self)
        self.connectionContinuation = continuation
        self.connectionStream = stream
        return stream
    }

    /// Start listening for connections.
    ///
    /// - Throws: If already listening or bind fails.
    public func start() async throws {
        guard !isListening else {
            throw SRTConnectionError.alreadyListening
        }

        // In full implementation: create UDPTransport, bind to port
        // For now, just mark as listening
        isListening = true

        // Ensure the connection stream is set up
        if connectionStream == nil {
            let (stream, continuation) = AsyncStream.makeStream(
                of: SRTSocket.self)
            self.connectionContinuation = continuation
            self.connectionStream = stream
        }
    }

    /// Stop the listener and close all connections.
    public func stop() async {
        isListening = false

        // Close all active connections
        for (_, socket) in activeConnections {
            await socket.close()
        }
        activeConnections.removeAll()
        activeConnectionCount = 0

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
