// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import NIOPosix

/// UDP transport layer for SRT connections.
///
/// Wraps NIO's `DatagramBootstrap` to provide UDP send/receive capabilities.
/// Manages the NIO EventLoopGroup lifecycle and the bound channel.
///
/// The transport layer is protocol-agnostic — it sends and receives raw
/// ByteBuffers. The SRT protocol logic is handled by higher layers.
public actor UDPTransport {
    /// Transport state.
    public enum State: String, Sendable {
        /// Initial state before binding.
        case idle
        /// Currently binding to the configured address.
        case binding
        /// Successfully bound and ready for I/O.
        case bound
        /// Currently connecting to a remote address.
        case connecting
        /// Connected to a remote peer.
        case connected
        /// Shutting down.
        case closing
        /// Shutdown complete.
        case closed
        /// An error occurred.
        case failed
    }

    /// Configuration for the UDP transport.
    public struct Configuration: Sendable {
        /// The local host address to bind to.
        public let host: String
        /// The local port to bind to (0 for ephemeral).
        public let port: Int
        /// Optional external EventLoopGroup (nil = create internal).
        public let eventLoopGroup: (any EventLoopGroup)?
        /// Receive buffer size in bytes.
        public let receiveBufferSize: Int
        /// Send buffer size in bytes.
        public let sendBufferSize: Int

        /// Creates a transport configuration.
        ///
        /// - Parameters:
        ///   - host: The local host address.
        ///   - port: The local port.
        ///   - eventLoopGroup: Optional external EventLoopGroup.
        ///   - receiveBufferSize: Receive buffer size.
        ///   - sendBufferSize: Send buffer size.
        public init(
            host: String = "0.0.0.0",
            port: Int = 4200,
            eventLoopGroup: (any EventLoopGroup)? = nil,
            receiveBufferSize: Int = 3_000_000,
            sendBufferSize: Int = 3_000_000
        ) {
            self.host = host
            self.port = port
            self.eventLoopGroup = eventLoopGroup
            self.receiveBufferSize = receiveBufferSize
            self.sendBufferSize = sendBufferSize
        }
    }

    /// The current transport state.
    public private(set) var state: State

    /// The local address this transport is bound to.
    public private(set) var localAddress: SocketAddress?

    /// Stream of incoming datagrams.
    public var incomingDatagrams: AsyncStream<IncomingDatagram> {
        guard let stream = datagramStream else {
            let (s, _) = AsyncStream<IncomingDatagram>.makeStream()
            return s
        }
        return stream
    }

    private let configuration: Configuration
    private let eventLoopGroup: any EventLoopGroup
    private let ownsEventLoopGroup: Bool
    private var channel: (any Channel)?
    private var datagramStream: AsyncStream<IncomingDatagram>?
    private var datagramContinuation: AsyncStream<IncomingDatagram>.Continuation?

    /// Creates a new UDP transport.
    ///
    /// - Parameter configuration: The transport configuration.
    public init(configuration: Configuration) {
        self.configuration = configuration
        self.state = .idle
        if let externalGroup = configuration.eventLoopGroup {
            self.eventLoopGroup = externalGroup
            self.ownsEventLoopGroup = false
        } else {
            self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            self.ownsEventLoopGroup = true
        }
    }

    /// Bind to the configured host:port (listener mode).
    ///
    /// - Returns: The actual local address after binding.
    /// - Throws: ``SRTError`` if binding fails.
    public func bind() async throws -> SocketAddress {
        guard state == .idle else {
            throw SRTError.connectionFailed("Cannot bind: already in state \(state)")
        }

        state = .binding

        let (stream, continuation) = AsyncStream<IncomingDatagram>.makeStream()
        self.datagramStream = stream
        self.datagramContinuation = continuation

        let handler = SRTDatagramHandler(continuation: continuation)

        do {
            let bootstrap = DatagramBootstrap(group: eventLoopGroup)
                .channelOption(
                    ChannelOptions.socketOption(.so_reuseaddr),
                    value: 1
                )
                .channelOption(
                    ChannelOptions.recvAllocator,
                    value: FixedSizeRecvByteBufferAllocator(
                        capacity: configuration.receiveBufferSize
                    )
                )
                .channelInitializer { channel in
                    channel.pipeline.addHandler(handler)
                }

            let boundChannel = try await bootstrap.bind(
                host: configuration.host,
                port: configuration.port
            ).get()

            self.channel = boundChannel
            self.localAddress = boundChannel.localAddress
            self.state = .bound

            guard let addr = boundChannel.localAddress else {
                throw SRTError.connectionFailed("No local address after bind")
            }
            return addr
        } catch let error as SRTError {
            state = .failed
            throw error
        } catch {
            state = .failed
            throw SRTError.connectionFailed(
                "Bind failed on \(configuration.host):\(configuration.port)"
            )
        }
    }

    /// Send a datagram to a specific remote address.
    ///
    /// - Parameters:
    ///   - buffer: Data to send.
    ///   - remoteAddress: Destination address.
    /// - Throws: ``SRTError`` if not bound or send fails.
    public func send(
        _ buffer: ByteBuffer,
        to remoteAddress: SocketAddress
    ) async throws {
        guard state == .bound || state == .connected else {
            throw SRTError.connectionFailed("Cannot send: not bound (state: \(state))")
        }
        guard let channel else {
            throw SRTError.connectionFailed("No channel available")
        }

        let envelope = AddressedEnvelope(remoteAddress: remoteAddress, data: buffer)
        try await channel.writeAndFlush(envelope)
    }

    /// Close the transport and release resources.
    ///
    /// Safe to call multiple times (idempotent).
    /// - Throws: ``SRTError`` if shutdown fails.
    public func close() async throws {
        guard state != .closed && state != .closing else { return }

        state = .closing
        datagramContinuation?.finish()

        if let channel {
            try await channel.close()
            self.channel = nil
        }

        if ownsEventLoopGroup {
            try await eventLoopGroup.shutdownGracefully()
        }

        state = .closed
    }
}
