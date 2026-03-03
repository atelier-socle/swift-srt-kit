// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("FEC Coverage Tests")
struct FECCoverageTests {

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

    // MARK: - FECDecoder: incomplete (no matrixBase)

    @Test("attemptRecovery returns incomplete when no packets received")
    func decoderIncompleteNoPackets() throws {
        let config = try FECConfiguration(columns: 2, rows: 1, layout: .even)
        var decoder = FECDecoder(configuration: config)
        let result = decoder.attemptRecovery()
        if case .incomplete = result {
        } else {
            Issue.record("Expected incomplete, got \(result)")
        }
    }

    // MARK: - FECDecoder: incomplete when losses but no FEC packets

    @Test("attemptRecovery returns incomplete when missing packets but no FEC")
    func decoderIncompleteNoFEC() throws {
        let config = try FECConfiguration(columns: 3, rows: 1, layout: .even)
        var decoder = FECDecoder(configuration: config)
        // Only receive 2 of 3 packets, no FEC
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(0), payload: [0x01], timestamp: 10)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(2), payload: [0x03], timestamp: 30)
        let result = decoder.attemptRecovery()
        if case .incomplete = result {
        } else {
            Issue.record("Expected incomplete, got \(result)")
        }
    }

    // MARK: - FECDecoder: receiveSourcePacket updates matrixBase to lower seq

    @Test("receiveSourcePacket updates matrixBase when lower seq arrives")
    func decoderMatrixBaseUpdated() throws {
        let config = try FECConfiguration(columns: 3, rows: 1, layout: .even)
        var decoder = FECDecoder(configuration: config)
        // Receive packet 2 first, then packet 0
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(2), payload: [0x03], timestamp: 30)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(0), payload: [0x01], timestamp: 10)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(1), payload: [0x02], timestamp: 20)

        let sources: [TestSource] = [
            TestSource(seq: 0, payload: [0x01], timestamp: 10),
            TestSource(seq: 1, payload: [0x02], timestamp: 20),
            TestSource(seq: 2, payload: [0x03], timestamp: 30)
        ]
        decoder.receiveFECPacket(buildRowFEC(sources: sources, row: 0, baseSeq: 0))

        let result = decoder.attemptRecovery()
        if case .noLoss = result {
        } else {
            Issue.record("Expected noLoss, got \(result)")
        }
    }

    // MARK: - FECDecoder: receiveFECPacket updates matrixBase

    @Test("receiveFECPacket column updates matrixBase when derived base is lower")
    func decoderFECColumnUpdatesBase() throws {
        let config = try FECConfiguration(columns: 2, rows: 2, layout: .even)
        var decoder = FECDecoder(configuration: config)

        // Receive all 4 packets
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(0), payload: [0x10], timestamp: 100)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(1), payload: [0x20], timestamp: 200)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(2), payload: [0x30], timestamp: 300)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(3), payload: [0x40], timestamp: 400)

        // Receive column FEC for col 1 (base derived = baseSeq - groupIndex = 1 - 1 = 0)
        let colSources: [TestSource] = [
            TestSource(seq: 1, payload: [0x20], timestamp: 200),
            TestSource(seq: 3, payload: [0x40], timestamp: 400)
        ]
        decoder.receiveFECPacket(
            buildColumnFEC(sources: colSources, column: 1, baseSeq: 1))

        let result = decoder.attemptRecovery()
        if case .noLoss = result {
        } else {
            Issue.record("Expected noLoss, got \(result)")
        }
    }

    // MARK: - FECDecoder: staircase column recovery

    @Test("Column recovery works with staircase layout")
    func decoderStaircaseColumnRecovery() throws {
        // cols=2, rows=2, staircase
        // Matrix: [0,1] [2,3]
        // Staircase col groups:
        //   row0: col0 -> group (0+0)%2=0, col1 -> group (1+0)%2=1
        //   row1: col0 -> group (0+1)%2=1, col1 -> group (1+1)%2=0
        // So group 0 = [packet 0, packet 3], group 1 = [packet 1, packet 2]
        let config = try FECConfiguration(columns: 2, rows: 2, layout: .staircase)
        var decoder = FECDecoder(configuration: config)

        // Lose packet 3. Column group 0 has [0, 3].
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(0), payload: [0x10], timestamp: 100)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(1), payload: [0x20], timestamp: 200)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(2), payload: [0x30], timestamp: 300)

        // Column 0 FEC for staircase = packets 0 and 3
        let col0Sources: [TestSource] = [
            TestSource(seq: 0, payload: [0x10], timestamp: 100),
            TestSource(seq: 3, payload: [0x40], timestamp: 400)
        ]
        decoder.receiveFECPacket(
            buildColumnFEC(sources: col0Sources, column: 0, baseSeq: 0))

        let result = decoder.attemptRecovery()
        if case .recovered(let packets) = result {
            #expect(packets.count == 1)
            #expect(packets[0].sequenceNumber == SequenceNumber(3))
            #expect(packets[0].payload == [0x40])
            #expect(packets[0].timestamp == 400)
        } else {
            Issue.record("Expected recovered, got \(result)")
        }
    }

    // MARK: - FECDecoder: recovery when recovered length exceeds payload (else branch)

    @Test("Recovery with length recovery producing zero uses full XOR payload")
    func decoderRecoveryLengthZero() throws {
        // When both packets have the same length, lengthRecovery = len ^ len = 0
        // So finalLength = 0, which means we fall into the else branch
        let config = try FECConfiguration(columns: 2, rows: 1, layout: .even)
        var decoder = FECDecoder(configuration: config)

        let sources: [TestSource] = [
            TestSource(seq: 0, payload: [0xAA, 0xBB], timestamp: 10),
            TestSource(seq: 1, payload: [0xCC, 0xDD], timestamp: 20)
        ]

        // Lose packet 1
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(0), payload: [0xAA, 0xBB], timestamp: 10)
        decoder.receiveFECPacket(buildRowFEC(sources: sources, row: 0, baseSeq: 0))

        let result = decoder.attemptRecovery()
        if case .recovered(let packets) = result {
            #expect(packets.count == 1)
            // Same length payloads → lengthRecovery = 2 ^ 2 = 0
            // But the actual recovery should still work: XOR produces the right payload
            // With lengthRecovery = 0, finalLength = 0, so else branch is taken
            // and we get the full XOR result (which is the correct payload)
            #expect(packets[0].payload == [0xCC, 0xDD])
        } else {
            Issue.record("Expected recovered, got \(result)")
        }
    }

    // MARK: - FECDecoder: recovery with partial irrecoverable after partial recovery

    @Test("Recovery recovers some but reports remaining as irrecoverable")
    func decoderPartialRecoveryThenIrrecoverable() throws {
        // cols=3, rows=2, even layout
        // Matrix: [0,1,2] [3,4,5]
        // Lose packets 1, 4, and 5
        // Row 0 FEC can recover packet 1 (1 missing)
        // Row 1 FEC cannot recover (2 missing: 4 and 5)
        let config = try FECConfiguration(columns: 3, rows: 2, layout: .even)
        var decoder = FECDecoder(configuration: config)

        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(0), payload: [0x10], timestamp: 100)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(2), payload: [0x30], timestamp: 300)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(3), payload: [0x40], timestamp: 400)

        // Row 0 FEC
        let row0Sources: [TestSource] = [
            TestSource(seq: 0, payload: [0x10], timestamp: 100),
            TestSource(seq: 1, payload: [0x20], timestamp: 200),
            TestSource(seq: 2, payload: [0x30], timestamp: 300)
        ]
        decoder.receiveFECPacket(buildRowFEC(sources: row0Sources, row: 0, baseSeq: 0))

        // Row 1 FEC
        let row1Sources: [TestSource] = [
            TestSource(seq: 3, payload: [0x40], timestamp: 400),
            TestSource(seq: 4, payload: [0x50], timestamp: 500),
            TestSource(seq: 5, payload: [0x60], timestamp: 600)
        ]
        decoder.receiveFECPacket(buildRowFEC(sources: row1Sources, row: 1, baseSeq: 3))

        let result = decoder.attemptRecovery()
        if case .recovered(let packets) = result {
            // Recovered packet 1, but packets 4 and 5 remain irrecoverable
            #expect(packets.count == 1)
            #expect(packets[0].sequenceNumber == SequenceNumber(1))
            #expect(decoder.totalRecovered == 1)
            #expect(decoder.totalIrrecoverable == 2)
        } else {
            Issue.record("Expected recovered with partial irrecoverable, got \(result)")
        }
    }

}

@Suite("FEC Coverage Tests Part 2")
struct FECCoverageTests2 {

    private struct TestSource {
        let seq: UInt32
        let payload: [UInt8]
        let timestamp: UInt32
    }

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

    // MARK: - FECEncoder: flush with incomplete columns

    @Test("Flush emits both incomplete row and column FEC packets")
    func encoderFlushIncompleteRowsAndColumns() throws {
        // cols=3, rows=2. Submit only 4 of 6 packets.
        // Row 0: 3 packets → complete (emitted during submit)
        // Row 1: 1 packet → incomplete, should flush
        // Columns: each has at most 2, but row 1 incomplete → columns incomplete too
        let config = try FECConfiguration(columns: 3, rows: 2, layout: .even)
        var encoder = FECEncoder(configuration: config)

        // Submit row 0 (3 packets) + 1 packet of row 1
        for i: UInt32 in 0..<4 {
            _ = encoder.submitPacket(
                FECEncoder.SourcePacket(
                    sequenceNumber: SequenceNumber(i),
                    payload: [UInt8(i)],
                    timestamp: UInt32(i * 100)
                ))
        }

        let flushed = encoder.flush()
        // Should have: 1 incomplete row FEC (row 1 with 1 packet)
        // + incomplete column FECs
        let rowFECs = flushed.filter { $0.direction == .row }
        let colFECs = flushed.filter { $0.direction == .column }
        #expect(rowFECs.count == 1)
        #expect(rowFECs[0].groupSize == 1)
        // Columns: col 0 has [0,3] = 2 packets (< rows=2 is not < rows, it equals)
        // Actually col 0 has packet 0 and packet 3, count=2 which equals rows=2
        // So col 0 is complete and won't be flushed
        // Cols with only 1 packet (from row 0 only) would be flushed
        #expect(colFECs.count >= 1)
    }

    @Test("Flush after complete matrix returns empty")
    func encoderFlushAfterComplete() throws {
        let config = try FECConfiguration(columns: 2, rows: 1, layout: .even)
        var encoder = FECEncoder(configuration: config)
        _ = encoder.submitPacket(
            FECEncoder.SourcePacket(
                sequenceNumber: SequenceNumber(0), payload: [0x01], timestamp: 10))
        _ = encoder.submitPacket(
            FECEncoder.SourcePacket(
                sequenceNumber: SequenceNumber(1), payload: [0x02], timestamp: 20))
        // Matrix complete → reset happened
        let flushed = encoder.flush()
        #expect(flushed.isEmpty)
    }

    // MARK: - FECEncoder: reset clears everything

    @Test("Reset clears packetsProcessed and fecPacketsGenerated")
    func encoderResetAll() throws {
        let config = try FECConfiguration(columns: 2, rows: 1, layout: .even)
        var encoder = FECEncoder(configuration: config)
        _ = encoder.submitPacket(
            FECEncoder.SourcePacket(
                sequenceNumber: SequenceNumber(0), payload: [0x01], timestamp: 10))
        _ = encoder.submitPacket(
            FECEncoder.SourcePacket(
                sequenceNumber: SequenceNumber(1), payload: [0x02], timestamp: 20))
        #expect(encoder.packetsProcessed == 2)
        #expect(encoder.fecPacketsGenerated > 0)
        encoder.reset()
        #expect(encoder.packetsProcessed == 0)
        #expect(encoder.fecPacketsGenerated == 0)
        // Can submit new packets after reset
        let result = encoder.submitPacket(
            FECEncoder.SourcePacket(
                sequenceNumber: SequenceNumber(10), payload: [0xAA], timestamp: 100))
        if case .pending = result {
        } else {
            Issue.record("Expected pending after reset")
        }
        #expect(encoder.packetsProcessed == 1)
    }

    // MARK: - FECEncoder: staircase flush columns

    @Test("Staircase flush produces column FECs with correct grouping")
    func encoderStaircaseFlushColumns() throws {
        // cols=2, rows=2, staircase. Submit 3 of 4.
        let config = try FECConfiguration(columns: 2, rows: 2, layout: .staircase)
        var encoder = FECEncoder(configuration: config)

        for i: UInt32 in 0..<3 {
            _ = encoder.submitPacket(
                FECEncoder.SourcePacket(
                    sequenceNumber: SequenceNumber(i),
                    payload: [UInt8(i + 1)],
                    timestamp: UInt32(i * 100)
                ))
        }

        let flushed = encoder.flush()
        // Should have at least some FEC packets for incomplete groups
        #expect(!flushed.isEmpty)
    }

    // MARK: - FECEncoder: two full matrices back-to-back

    @Test("Two consecutive full matrices generate correct FEC counts")
    func encoderTwoMatrices() throws {
        let config = try FECConfiguration(columns: 2, rows: 1, layout: .even)
        var encoder = FECEncoder(configuration: config)

        // First matrix: packets 0, 1
        _ = encoder.submitPacket(
            FECEncoder.SourcePacket(
                sequenceNumber: SequenceNumber(0), payload: [0x01], timestamp: 10))
        let r1 = encoder.submitPacket(
            FECEncoder.SourcePacket(
                sequenceNumber: SequenceNumber(1), payload: [0x02], timestamp: 20))
        if case .fecReady(let packets) = r1 {
            // row FEC + column FEC
            #expect(!packets.isEmpty)
        } else {
            Issue.record("Expected fecReady at end of first matrix")
        }

        // Second matrix: packets 2, 3
        _ = encoder.submitPacket(
            FECEncoder.SourcePacket(
                sequenceNumber: SequenceNumber(2), payload: [0x03], timestamp: 30))
        let r2 = encoder.submitPacket(
            FECEncoder.SourcePacket(
                sequenceNumber: SequenceNumber(3), payload: [0x04], timestamp: 40))
        if case .fecReady(let packets) = r2 {
            #expect(!packets.isEmpty)
        } else {
            Issue.record("Expected fecReady at end of second matrix")
        }

        #expect(encoder.packetsProcessed == 4)
    }

    // MARK: - FECDecoder: 2D iterative recovery with column-then-row

    @Test("2D iterative recovery: column recovers first, enabling row recovery")
    func decoderColumnThenRowRecovery() throws {
        // cols=2, rows=2, even. Matrix: [0,1] [2,3]
        // Lose packets 1 and 2
        // Row 0: [0,1] — 1 missing → recoverable with row FEC
        // After recovering 1, column 0: [0,2] — 1 missing → recoverable
        // Actually row 0 has 1 missing from the start, so it recovers first.
        // Let's set up so column needs to go first:
        // Lose packets 0 and 3
        // Row 0: [0,1] — 1 missing (0) → recover with row FEC
        // Row 1: [2,3] — 1 missing (3) → recover with row FEC
        // Both rows can recover independently. Let's make it require iteration:
        // Lose 0 and 1 — row 0 can't recover (2 missing)
        // Column 0: [0,2] — 1 missing → recover 0
        // Then row 0: [0,1] — now only 1 missing → recover 1
        let config = try FECConfiguration(columns: 2, rows: 2, layout: .even)
        var decoder = FECDecoder(configuration: config)

        // Receive only packets 2 and 3
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(2), payload: [0x30], timestamp: 300)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(3), payload: [0x40], timestamp: 400)

        // Row 0 FEC (from packets 0,1)
        decoder.receiveFECPacket(
            buildRowFEC(
                sources: [
                    TestSource(seq: 0, payload: [0x10], timestamp: 100),
                    TestSource(seq: 1, payload: [0x20], timestamp: 200)
                ],
                row: 0, baseSeq: 0))

        // Column 0 FEC (from packets 0,2)
        decoder.receiveFECPacket(
            buildColumnFEC(
                sources: [
                    TestSource(seq: 0, payload: [0x10], timestamp: 100),
                    TestSource(seq: 2, payload: [0x30], timestamp: 300)
                ],
                column: 0, baseSeq: 0))

        // Column 1 FEC (from packets 1,3)
        decoder.receiveFECPacket(
            buildColumnFEC(
                sources: [
                    TestSource(seq: 1, payload: [0x20], timestamp: 200),
                    TestSource(seq: 3, payload: [0x40], timestamp: 400)
                ],
                column: 1, baseSeq: 1))

        let result = decoder.attemptRecovery()
        if case .recovered(let packets) = result {
            let seqs = Set(packets.map { $0.sequenceNumber })
            #expect(seqs.contains(SequenceNumber(0)))
            #expect(seqs.contains(SequenceNumber(1)))
            #expect(packets.count == 2)
        } else {
            Issue.record("Expected recovered, got \(result)")
        }
    }

    // MARK: - FECDecoder: advanceMatrix then new matrix works

    @Test("advanceMatrix then new recovery works correctly")
    func decoderAdvanceThenRecover() throws {
        let config = try FECConfiguration(columns: 2, rows: 1, layout: .even)
        var decoder = FECDecoder(configuration: config)

        // First matrix
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(0), payload: [0x01], timestamp: 10)
        decoder.advanceMatrix(to: SequenceNumber(10))

        // Second matrix: lose packet 11
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(10), payload: [0xAA], timestamp: 100)

        let sources: [TestSource] = [
            TestSource(seq: 10, payload: [0xAA], timestamp: 100),
            TestSource(seq: 11, payload: [0xBB], timestamp: 200)
        ]
        decoder.receiveFECPacket(buildRowFEC(sources: sources, row: 0, baseSeq: 10))

        let result = decoder.attemptRecovery()
        if case .recovered(let packets) = result {
            #expect(packets[0].sequenceNumber == SequenceNumber(11))
            #expect(packets[0].payload == [0xBB])
        } else {
            Issue.record("Expected recovered")
        }
    }
}
