// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("FECDecoder Tests")
struct FECDecoderTests {
    /// A source packet descriptor for test helpers.
    private struct TestSource {
        let seq: UInt32
        let payload: [UInt8]
        let timestamp: UInt32
    }

    /// Helper: build a row FEC packet from source packets.
    private func buildRowFEC(
        sources: [TestSource],
        row: Int,
        baseSeq: UInt32
    ) -> FECPacket {
        var payloadXOR: [UInt8] = []
        var lengthRecovery: UInt16 = 0
        var timestampRecovery: UInt32 = 0
        for src in sources {
            payloadXOR = XORHelper.xor(payloadXOR, src.payload)
            lengthRecovery ^= UInt16(src.payload.count)
            timestampRecovery ^= src.timestamp
        }
        return FECPacket(
            payloadXOR: payloadXOR,
            lengthRecovery: lengthRecovery,
            timestampRecovery: timestampRecovery,
            baseSequenceNumber: SequenceNumber(baseSeq),
            direction: .row,
            groupSize: sources.count,
            groupIndex: row
        )
    }

    /// Helper: build a column FEC packet from source packets.
    private func buildColumnFEC(
        sources: [TestSource],
        column: Int,
        baseSeq: UInt32
    ) -> FECPacket {
        var payloadXOR: [UInt8] = []
        var lengthRecovery: UInt16 = 0
        var timestampRecovery: UInt32 = 0
        for src in sources {
            payloadXOR = XORHelper.xor(payloadXOR, src.payload)
            lengthRecovery ^= UInt16(src.payload.count)
            timestampRecovery ^= src.timestamp
        }
        return FECPacket(
            payloadXOR: payloadXOR,
            lengthRecovery: lengthRecovery,
            timestampRecovery: timestampRecovery,
            baseSequenceNumber: SequenceNumber(baseSeq),
            direction: .column,
            groupSize: sources.count,
            groupIndex: column
        )
    }

    // MARK: - Row recovery

    @Test("Recover 1 missing packet in row via row FEC")
    func rowRecoverySingle() throws {
        // cols=3, rows=1. Packets: 0,1,2. Lose packet 1.
        let config = try FECConfiguration(columns: 3, rows: 1, layout: .even)
        var decoder = FECDecoder(configuration: config)

        let sources: [TestSource] = [
            TestSource(seq: 0, payload: [0x10, 0x20], timestamp: 100),
            TestSource(seq: 1, payload: [0x30, 0x40], timestamp: 200),
            TestSource(seq: 2, payload: [0x50, 0x60], timestamp: 300)
        ]

        // Receive packets 0 and 2 (lose packet 1)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(0), payload: [0x10, 0x20], timestamp: 100)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(2), payload: [0x50, 0x60], timestamp: 300)

        // Build and receive row FEC from all 3 packets
        let fec = buildRowFEC(sources: sources, row: 0, baseSeq: 0)
        decoder.receiveFECPacket(fec)

        let result = decoder.attemptRecovery()
        if case .recovered(let packets) = result {
            #expect(packets.count == 1)
            #expect(packets[0].sequenceNumber == SequenceNumber(1))
            #expect(packets[0].payload == [0x30, 0x40])
            #expect(packets[0].timestamp == 200)
        } else {
            Issue.record("Expected recovered, got \(result)")
        }
    }

    @Test("Recover first packet in row")
    func rowRecoverFirst() throws {
        let config = try FECConfiguration(columns: 3, rows: 1, layout: .even)
        var decoder = FECDecoder(configuration: config)

        let sources: [TestSource] = [
            TestSource(seq: 0, payload: [0xAA], timestamp: 10),
            TestSource(seq: 1, payload: [0xBB], timestamp: 20),
            TestSource(seq: 2, payload: [0xCC], timestamp: 30)
        ]

        // Lose packet 0
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(1), payload: [0xBB], timestamp: 20)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(2), payload: [0xCC], timestamp: 30)
        decoder.receiveFECPacket(buildRowFEC(sources: sources, row: 0, baseSeq: 0))

        let result = decoder.attemptRecovery()
        if case .recovered(let packets) = result {
            #expect(packets[0].sequenceNumber == SequenceNumber(0))
            #expect(packets[0].payload == [0xAA])
        } else {
            Issue.record("Expected recovered")
        }
    }

    @Test("Recover last packet in row")
    func rowRecoverLast() throws {
        let config = try FECConfiguration(columns: 3, rows: 1, layout: .even)
        var decoder = FECDecoder(configuration: config)

        let sources: [TestSource] = [
            TestSource(seq: 0, payload: [0x01], timestamp: 10),
            TestSource(seq: 1, payload: [0x02], timestamp: 20),
            TestSource(seq: 2, payload: [0x03], timestamp: 30)
        ]

        // Lose packet 2
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(0), payload: [0x01], timestamp: 10)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(1), payload: [0x02], timestamp: 20)
        decoder.receiveFECPacket(buildRowFEC(sources: sources, row: 0, baseSeq: 0))

        let result = decoder.attemptRecovery()
        if case .recovered(let packets) = result {
            #expect(packets[0].payload == [0x03])
            #expect(packets[0].timestamp == 30)
        } else {
            Issue.record("Expected recovered")
        }
    }

    // MARK: - Column recovery

    @Test("Recover 1 missing packet via column FEC")
    func columnRecovery() throws {
        // cols=2, rows=2. Matrix: [0,1][2,3]
        // Col 0: packets 0,2. Lose packet 2.
        let config = try FECConfiguration(columns: 2, rows: 2, layout: .even)
        var decoder = FECDecoder(configuration: config)

        let colSources: [TestSource] = [
            TestSource(seq: 0, payload: [0xAA], timestamp: 100),
            TestSource(seq: 2, payload: [0xBB], timestamp: 300)
        ]

        // Receive packets 0,1,3 (lose 2)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(0), payload: [0xAA], timestamp: 100)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(1), payload: [0x11], timestamp: 200)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(3), payload: [0x22], timestamp: 400)

        // Column 0 FEC (from packets 0 and 2)
        decoder.receiveFECPacket(
            buildColumnFEC(sources: colSources, column: 0, baseSeq: 0))

        let result = decoder.attemptRecovery()
        if case .recovered(let packets) = result {
            #expect(packets.count == 1)
            #expect(packets[0].sequenceNumber == SequenceNumber(2))
            #expect(packets[0].payload == [0xBB])
        } else {
            Issue.record("Expected recovered")
        }
    }

    // MARK: - 2D iterative recovery

    @Test("2 losses in different rows and columns recovered iteratively")
    func iterative2DRecovery() throws {
        // cols=2, rows=2. Matrix: [0,1][2,3]
        // Lose packets 1 and 2.
        // Row 0: [0,1], lose 1 → recoverable (have FEC + packet 0)
        // Row 1: [2,3], lose 2 → recoverable (have FEC + packet 3)
        let config = try FECConfiguration(columns: 2, rows: 2, layout: .even)
        var decoder = FECDecoder(configuration: config)

        // Receive 0 and 3 only
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(0), payload: [0x10], timestamp: 100)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(3), payload: [0x40], timestamp: 400)

        // Row 0 FEC (from 0,1) — row base = 0
        decoder.receiveFECPacket(
            buildRowFEC(
                sources: [
                    TestSource(seq: 0, payload: [0x10], timestamp: 100),
                    TestSource(seq: 1, payload: [0x20], timestamp: 200)
                ],
                row: 0, baseSeq: 0))
        // Row 1 FEC (from 2,3) — row base = 2
        decoder.receiveFECPacket(
            buildRowFEC(
                sources: [
                    TestSource(seq: 2, payload: [0x30], timestamp: 300),
                    TestSource(seq: 3, payload: [0x40], timestamp: 400)
                ],
                row: 1, baseSeq: 2))

        let result = decoder.attemptRecovery()
        if case .recovered(let packets) = result {
            #expect(packets.count == 2)
            let seqs = Set(packets.map { $0.sequenceNumber })
            #expect(seqs.contains(SequenceNumber(1)))
            #expect(seqs.contains(SequenceNumber(2)))
        } else {
            Issue.record("Expected 2D recovery, got \(result)")
        }
    }
}
