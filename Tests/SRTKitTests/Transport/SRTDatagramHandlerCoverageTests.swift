// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("SRTDatagramHandler Coverage Tests")
struct SRTDatagramHandlerCoverageTests {

    @Test("SRTDatagramHandler can be created with a continuation")
    func handlerCreation() {
        let (_, continuation) = AsyncStream<IncomingDatagram>.makeStream()
        let handler = SRTDatagramHandler(continuation: continuation)
        _ = handler
        continuation.finish()
    }

    @Test("IncomingDatagram stores data and remote address")
    func incomingDatagramFields() throws {
        let buffer = ByteBuffer(bytes: [0x01, 0x02, 0x03])
        let address = try SocketAddress(ipAddress: "127.0.0.1", port: 9000)
        let datagram = IncomingDatagram(data: buffer, remoteAddress: address)
        #expect(datagram.data.readableBytes == 3)
        #expect(datagram.remoteAddress == address)
    }

    @Test("AsyncStream receives datagrams yielded to continuation")
    func streamReceivesDatagram() async throws {
        let (stream, continuation) = AsyncStream<IncomingDatagram>.makeStream()
        _ = SRTDatagramHandler(continuation: continuation)

        // Yield a datagram through the continuation (simulating channelRead)
        let buffer = ByteBuffer(bytes: [0xDE, 0xAD])
        let address = try SocketAddress(ipAddress: "192.168.1.1", port: 5000)
        let datagram = IncomingDatagram(data: buffer, remoteAddress: address)
        continuation.yield(datagram)
        continuation.finish()

        var received: [IncomingDatagram] = []
        for await d in stream {
            received.append(d)
        }
        #expect(received.count == 1)
        #expect(received[0].data.readableBytes == 2)
    }

    @Test("Continuation finish terminates the stream")
    func continuationFinishTerminatesStream() async {
        let (stream, continuation) = AsyncStream<IncomingDatagram>.makeStream()
        _ = SRTDatagramHandler(continuation: continuation)

        // Finishing the continuation without yielding should produce an empty stream
        continuation.finish()

        var count = 0
        for await _ in stream {
            count += 1
        }
        #expect(count == 0)
    }

    @Test("Multiple datagrams are received in order")
    func multipleDatagramsInOrder() async throws {
        let (stream, continuation) = AsyncStream<IncomingDatagram>.makeStream()
        _ = SRTDatagramHandler(continuation: continuation)

        let address = try SocketAddress(ipAddress: "10.0.0.1", port: 3000)
        for i: UInt8 in 0..<5 {
            let buffer = ByteBuffer(bytes: [i])
            continuation.yield(IncomingDatagram(data: buffer, remoteAddress: address))
        }
        continuation.finish()

        var received: [[UInt8]] = []
        for await d in stream {
            var buf = d.data
            if let bytes = buf.readBytes(length: buf.readableBytes) {
                received.append(bytes)
            }
        }
        #expect(received.count == 5)
        for i: UInt8 in 0..<5 {
            #expect(received[Int(i)] == [i])
        }
    }
}
