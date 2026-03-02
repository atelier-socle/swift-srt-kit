// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore

/// NIO channel handler that receives UDP datagrams and forwards them
/// to an AsyncStream for consumption by the SRT protocol layer.
///
/// This is an internal implementation detail of ``UDPTransport``.
///
/// `@unchecked Sendable` is allowed here because NIO channel handlers
/// are confined to a single EventLoop and never accessed concurrently.
/// This is the standard NIO pattern. See:
/// https://github.com/apple/swift-nio/blob/main/Sources/NIOCore/ChannelHandler.swift
///
/// All other types in the codebase MUST NOT use `@unchecked Sendable`.
final class SRTDatagramHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = AddressedEnvelope<ByteBuffer>

    private let continuation: AsyncStream<IncomingDatagram>.Continuation

    /// Creates a datagram handler.
    ///
    /// - Parameter continuation: The stream continuation to yield datagrams into.
    init(continuation: AsyncStream<IncomingDatagram>.Continuation) {
        self.continuation = continuation
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let envelope = unwrapInboundIn(data)
        let datagram = IncomingDatagram(
            data: envelope.data,
            remoteAddress: envelope.remoteAddress
        )
        continuation.yield(datagram)
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        // UDP errors are non-fatal — log and continue
        context.fireErrorCaught(error)
    }

    func channelInactive(context: ChannelHandlerContext) {
        continuation.finish()
        context.fireChannelInactive()
    }
}
