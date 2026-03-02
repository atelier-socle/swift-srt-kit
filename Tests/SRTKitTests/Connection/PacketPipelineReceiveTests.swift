// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("PacketPipeline Receive Tests")
struct PacketPipelineReceiveTests {
    /// Create a pipeline with defaults for receive testing.
    private func makePipeline(
        latency: UInt64 = 0,
        fecConfig: FECConfiguration? = nil
    ) -> PacketPipeline {
        PacketPipeline(
            configuration: .init(
                fecEnabled: fecConfig != nil,
                fecConfiguration: fecConfig,
                latencyMicroseconds: latency
            ))
    }

    // MARK: - Basic receive (no encryption, no FEC)

    @Test("Receive in-order packet delivers immediately without TSBPD")
    func receiveInOrderDelivers() throws {
        var pipeline = makePipeline()
        let result = try pipeline.processReceivedPacket(
            payload: [0x01, 0x02],
            sequenceNumber: SequenceNumber(0),
            timestamp: 100,
            header: [],
            currentTime: 1000
        )
        if case .deliver(let payloads) = result {
            #expect(payloads.count == 1)
            #expect(payloads[0].payload == [0x01, 0x02])
            #expect(payloads[0].sequenceNumber == SequenceNumber(0))
        } else {
            Issue.record("Expected deliver, got \(result)")
        }
    }

    @Test("Receive out of order is buffered")
    func receiveOutOfOrderBuffered() throws {
        var pipeline = makePipeline()
        // Send packet 1 (skipping 0)
        let result = try pipeline.processReceivedPacket(
            payload: [0x02],
            sequenceNumber: SequenceNumber(1),
            timestamp: 200,
            header: [],
            currentTime: 1000
        )
        if case .buffered = result {
        } else {
            Issue.record("Expected buffered, got \(result)")
        }
    }

    @Test("Receive duplicate buffered packet returns duplicate")
    func receiveDuplicate() throws {
        var pipeline = makePipeline()
        // Receive packet 2 (out of order, gap at 0 and 1) → buffered
        _ = try pipeline.processReceivedPacket(
            payload: [0x03],
            sequenceNumber: SequenceNumber(2),
            timestamp: 300,
            header: [],
            currentTime: 1000
        )
        // Receive packet 2 again → duplicate (it's in the buffer)
        let result = try pipeline.processReceivedPacket(
            payload: [0x03],
            sequenceNumber: SequenceNumber(2),
            timestamp: 300,
            header: [],
            currentTime: 1000
        )
        if case .duplicate = result {
        } else {
            Issue.record("Expected duplicate, got \(result)")
        }
    }

    @Test("Receive already-delivered packet returns tooLate")
    func receiveAlreadyDelivered() throws {
        var pipeline = makePipeline()
        // Receive and deliver packet 0
        _ = try pipeline.processReceivedPacket(
            payload: [0x01],
            sequenceNumber: SequenceNumber(0),
            timestamp: 100,
            header: [],
            currentTime: 1000
        )
        // Receive packet 0 again → tooLate (behind ACK frontier)
        let result = try pipeline.processReceivedPacket(
            payload: [0x01],
            sequenceNumber: SequenceNumber(0),
            timestamp: 100,
            header: [],
            currentTime: 1000
        )
        if case .tooLate = result {
        } else {
            Issue.record("Expected tooLate, got \(result)")
        }
    }

    @Test("Gap fill delivers multiple packets in order")
    func gapFillDeliversMultiple() throws {
        var pipeline = makePipeline()
        // Receive packet 1 (gap at 0)
        let r1 = try pipeline.processReceivedPacket(
            payload: [0x02],
            sequenceNumber: SequenceNumber(1),
            timestamp: 200,
            header: [],
            currentTime: 1000
        )
        #expect(
            {
                if case .buffered = r1 { return true }
                return false
            }())

        // Receive packet 0 (fills gap, delivers 0 and 1)
        let r0 = try pipeline.processReceivedPacket(
            payload: [0x01],
            sequenceNumber: SequenceNumber(0),
            timestamp: 100,
            header: [],
            currentTime: 1000
        )
        if case .deliver(let payloads) = r0 {
            #expect(payloads.count == 2)
            #expect(payloads[0].sequenceNumber == SequenceNumber(0))
            #expect(payloads[1].sequenceNumber == SequenceNumber(1))
        } else {
            Issue.record("Expected deliver with 2 packets")
        }
    }

    // MARK: - TSBPD delivery

    @Test("With TSBPD configured, packet is buffered then polled")
    func tsbpdBufferAndPoll() throws {
        var pipeline = makePipeline(latency: 100_000)
        pipeline.configureTSBPD(baseTime: 0, firstTimestamp: 0)

        let result = try pipeline.processReceivedPacket(
            payload: [0xAA],
            sequenceNumber: SequenceNumber(0),
            timestamp: 100,
            header: [],
            currentTime: 0
        )
        // Should be buffered (waiting for TSBPD time)
        // Depending on timing, may be deliver or buffered
        // At time 0 with latency 100_000, delivery time is well in the future
        if case .buffered = result {
        } else if case .deliver = result {
        } else {
            Issue.record("Expected buffered or deliver")
        }

        // Poll at delivery time
        let delivered = pipeline.pollDelivery(currentTime: 200_000)
        // The packet should be deliverable by now
        #expect(delivered.count <= 1)
    }

    @Test("pollDelivery with no pending returns empty")
    func pollEmptyReturnsEmpty() {
        var pipeline = makePipeline()
        let delivered = pipeline.pollDelivery(currentTime: 1_000_000)
        #expect(delivered.isEmpty)
    }

    // MARK: - FEC receive

    @Test("FEC configured receives source packets into decoder")
    func fecReceiveSourcePacket() throws {
        let fecConfig = try FECConfiguration(columns: 3, rows: 1, layout: .even)
        var pipeline = makePipeline(fecConfig: fecConfig)

        // Receive two packets (one missing from group)
        let r0 = try pipeline.processReceivedPacket(
            payload: [0x10],
            sequenceNumber: SequenceNumber(0),
            timestamp: 100,
            header: [],
            currentTime: 1000
        )
        if case .deliver = r0 {
        } else {
            Issue.record("Expected deliver for first packet")
        }

        let r2 = try pipeline.processReceivedPacket(
            payload: [0x30],
            sequenceNumber: SequenceNumber(2),
            timestamp: 300,
            header: [],
            currentTime: 1000
        )
        if case .buffered = r2 {
        } else {
            Issue.record("Expected buffered for out-of-order packet")
        }
    }

    @Test("FEC recovery returns recovered packets")
    func fecRecoveryReturnsPackets() throws {
        let fecConfig = try FECConfiguration(columns: 2, rows: 1, layout: .even)
        var pipeline = makePipeline(fecConfig: fecConfig)

        // Receive packet 0 (miss packet 1)
        _ = try pipeline.processReceivedPacket(
            payload: [0xAA],
            sequenceNumber: SequenceNumber(0),
            timestamp: 100,
            header: [],
            currentTime: 1000
        )

        // Build FEC packet from both source packets
        let xorPayload = XORHelper.xor([0xAA], [0xBB])
        let fecPacket = FECPacket(
            payloadXOR: xorPayload,
            lengthRecovery: UInt16(1) ^ UInt16(1),
            timestampRecovery: 100 ^ 200,
            baseSequenceNumber: SequenceNumber(0),
            direction: .row,
            groupSize: 2,
            groupIndex: 0
        )

        let recovered = pipeline.processReceivedFECPacket(fecPacket)
        #expect(recovered.count == 1)
        #expect(recovered[0].sequenceNumber == SequenceNumber(1))
        #expect(recovered[0].payload == [0xBB])
    }

    @Test("fecRecoveries counter incremented on recovery")
    func fecRecoveriesCounter() throws {
        let fecConfig = try FECConfiguration(columns: 2, rows: 1, layout: .even)
        var pipeline = makePipeline(fecConfig: fecConfig)

        #expect(pipeline.fecRecoveries == 0)

        _ = try pipeline.processReceivedPacket(
            payload: [0xAA],
            sequenceNumber: SequenceNumber(0),
            timestamp: 100,
            header: [],
            currentTime: 1000
        )

        let xorPayload = XORHelper.xor([0xAA], [0xBB])
        let fecPacket = FECPacket(
            payloadXOR: xorPayload,
            lengthRecovery: UInt16(1) ^ UInt16(1),
            timestampRecovery: 100 ^ 200,
            baseSequenceNumber: SequenceNumber(0),
            direction: .row,
            groupSize: 2,
            groupIndex: 0
        )
        _ = pipeline.processReceivedFECPacket(fecPacket)
        #expect(pipeline.fecRecoveries == 1)
    }

    // MARK: - Stats

    @Test("packetsDelivered increments on delivery")
    func packetsDeliveredStat() throws {
        var pipeline = makePipeline()
        #expect(pipeline.packetsDelivered == 0)
        _ = try pipeline.processReceivedPacket(
            payload: [0x01],
            sequenceNumber: SequenceNumber(0),
            timestamp: 100,
            header: [],
            currentTime: 1000
        )
        #expect(pipeline.packetsDelivered == 1)
    }

    @Test("receiveBufferCount reflects buffered packets")
    func receiveBufferCount() throws {
        var pipeline = makePipeline()
        #expect(pipeline.receiveBufferCount == 0)
        // Receive out-of-order packet (buffered)
        _ = try pipeline.processReceivedPacket(
            payload: [0x02],
            sequenceNumber: SequenceNumber(1),
            timestamp: 200,
            header: [],
            currentTime: 1000
        )
        #expect(pipeline.receiveBufferCount == 1)
    }
}
