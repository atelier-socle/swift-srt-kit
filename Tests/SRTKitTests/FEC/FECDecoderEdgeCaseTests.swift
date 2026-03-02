// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("FECDecoder Edge Case Tests")
struct FECDecoderEdgeCaseTests {
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

    // MARK: - Irrecoverable

    @Test("2 losses in same row with no column FEC is irrecoverable")
    func irrecoverableSameRow() throws {
        let config = try FECConfiguration(columns: 3, rows: 1, layout: .even)
        var decoder = FECDecoder(configuration: config)

        let sources: [TestSource] = [
            TestSource(seq: 0, payload: [0x01], timestamp: 10),
            TestSource(seq: 1, payload: [0x02], timestamp: 20),
            TestSource(seq: 2, payload: [0x03], timestamp: 30)
        ]

        // Lose packets 0 and 1
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(2), payload: [0x03], timestamp: 30)
        decoder.receiveFECPacket(buildRowFEC(sources: sources, row: 0, baseSeq: 0))

        let result = decoder.attemptRecovery()
        if case .irrecoverable(let count) = result {
            #expect(count == 2)
        } else {
            Issue.record("Expected irrecoverable")
        }
    }

    @Test("2 losses in same row AND same column irrecoverable with 2D FEC")
    func irrecoverable2DSameRowCol() throws {
        // cols=2, rows=2. Lose packets 0 and 1 (same row 0)
        // Row 0 can't recover (2 missing). Col 0 has [0,2] (1 missing),
        // Col 1 has [1,3] (1 missing).
        // BUT without col FEC, cannot recover.
        let config = try FECConfiguration(columns: 2, rows: 2, layout: .even)
        var decoder = FECDecoder(configuration: config)

        // Receive only 2 and 3
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(2), payload: [0x30], timestamp: 300)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(3), payload: [0x40], timestamp: 400)

        // Only row FECs (no column FECs)
        decoder.receiveFECPacket(
            buildRowFEC(
                sources: [
                    TestSource(seq: 0, payload: [0x10], timestamp: 100),
                    TestSource(seq: 1, payload: [0x20], timestamp: 200)
                ],
                row: 0, baseSeq: 0))
        decoder.receiveFECPacket(
            buildRowFEC(
                sources: [
                    TestSource(seq: 2, payload: [0x30], timestamp: 300),
                    TestSource(seq: 3, payload: [0x40], timestamp: 400)
                ],
                row: 1, baseSeq: 2))

        let result = decoder.attemptRecovery()
        if case .irrecoverable(let count) = result {
            #expect(count == 2)
        } else {
            Issue.record("Expected irrecoverable")
        }
    }

    // MARK: - No loss

    @Test("All packets received returns noLoss")
    func noLoss() throws {
        let config = try FECConfiguration(columns: 2, rows: 1, layout: .even)
        var decoder = FECDecoder(configuration: config)

        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(0), payload: [0x01], timestamp: 10)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(1), payload: [0x02], timestamp: 20)

        let sources: [TestSource] = [
            TestSource(seq: 0, payload: [0x01], timestamp: 10),
            TestSource(seq: 1, payload: [0x02], timestamp: 20)
        ]
        decoder.receiveFECPacket(buildRowFEC(sources: sources, row: 0, baseSeq: 0))

        let result = decoder.attemptRecovery()
        if case .noLoss = result {
        } else {
            Issue.record("Expected noLoss")
        }
    }

    // MARK: - Edge cases

    @Test("Single-column config (cols=1) uses column FEC")
    func singleColumn() throws {
        let config = try FECConfiguration(columns: 1, rows: 3, layout: .even)
        var decoder = FECDecoder(configuration: config)

        // Matrix: [0][1][2] — each row has 1 packet
        // Col 0: packets 0,1,2. Lose packet 1.
        let colSources: [TestSource] = [
            TestSource(seq: 0, payload: [0xAA], timestamp: 10),
            TestSource(seq: 1, payload: [0xBB], timestamp: 20),
            TestSource(seq: 2, payload: [0xCC], timestamp: 30)
        ]

        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(0), payload: [0xAA], timestamp: 10)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(2), payload: [0xCC], timestamp: 30)

        decoder.receiveFECPacket(
            buildColumnFEC(sources: colSources, column: 0, baseSeq: 0))

        let result = decoder.attemptRecovery()
        if case .recovered(let packets) = result {
            #expect(packets[0].sequenceNumber == SequenceNumber(1))
            #expect(packets[0].payload == [0xBB])
        } else {
            Issue.record("Expected recovered")
        }
    }

    @Test("Single-row config (rows=1) uses row FEC only")
    func singleRow() throws {
        let config = try FECConfiguration(columns: 3, rows: 1, layout: .even)
        var decoder = FECDecoder(configuration: config)

        let sources: [TestSource] = [
            TestSource(seq: 0, payload: [0x01], timestamp: 10),
            TestSource(seq: 1, payload: [0x02], timestamp: 20),
            TestSource(seq: 2, payload: [0x03], timestamp: 30)
        ]

        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(0), payload: [0x01], timestamp: 10)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(2), payload: [0x03], timestamp: 30)

        decoder.receiveFECPacket(buildRowFEC(sources: sources, row: 0, baseSeq: 0))

        let result = decoder.attemptRecovery()
        if case .recovered(let packets) = result {
            #expect(packets[0].payload == [0x02])
        } else {
            Issue.record("Expected recovered")
        }
    }

    @Test("Duplicate source packet is handled gracefully")
    func duplicatePacket() throws {
        let config = try FECConfiguration(columns: 2, rows: 1, layout: .even)
        var decoder = FECDecoder(configuration: config)

        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(0), payload: [0x01], timestamp: 10)
        // Duplicate
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(0), payload: [0x01], timestamp: 10)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(1), payload: [0x02], timestamp: 20)

        let sources: [TestSource] = [
            TestSource(seq: 0, payload: [0x01], timestamp: 10),
            TestSource(seq: 1, payload: [0x02], timestamp: 20)
        ]
        decoder.receiveFECPacket(buildRowFEC(sources: sources, row: 0, baseSeq: 0))

        let result = decoder.attemptRecovery()
        if case .noLoss = result {
        } else {
            Issue.record("Expected noLoss")
        }
    }

    @Test("advanceMatrix clears state")
    func advanceMatrixClears() throws {
        let config = try FECConfiguration(columns: 2, rows: 1, layout: .even)
        var decoder = FECDecoder(configuration: config)

        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(0), payload: [0x01], timestamp: 10)
        decoder.advanceMatrix(to: SequenceNumber(100))

        // After advance, old packets are gone
        let result = decoder.attemptRecovery()
        if case .incomplete = result {
        } else {
            Issue.record("Expected incomplete after advance")
        }
    }

    // MARK: - Stats

    @Test("totalRecovered increments")
    func totalRecoveredStat() throws {
        let config = try FECConfiguration(columns: 2, rows: 1, layout: .even)
        var decoder = FECDecoder(configuration: config)

        let sources: [TestSource] = [
            TestSource(seq: 0, payload: [0x01], timestamp: 10),
            TestSource(seq: 1, payload: [0x02], timestamp: 20)
        ]
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(0), payload: [0x01], timestamp: 10)
        decoder.receiveFECPacket(buildRowFEC(sources: sources, row: 0, baseSeq: 0))

        _ = decoder.attemptRecovery()
        #expect(decoder.totalRecovered == 1)
    }

    @Test("totalIrrecoverable increments on failure")
    func totalIrrecoverableStat() throws {
        let config = try FECConfiguration(columns: 3, rows: 1, layout: .even)
        var decoder = FECDecoder(configuration: config)

        let sources: [TestSource] = [
            TestSource(seq: 0, payload: [0x01], timestamp: 10),
            TestSource(seq: 1, payload: [0x02], timestamp: 20),
            TestSource(seq: 2, payload: [0x03], timestamp: 30)
        ]
        // Lose 2 packets — irrecoverable with row-only FEC
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(2), payload: [0x03], timestamp: 30)
        decoder.receiveFECPacket(buildRowFEC(sources: sources, row: 0, baseSeq: 0))

        _ = decoder.attemptRecovery()
        #expect(decoder.totalIrrecoverable == 2)
    }

    @Test("Reset clears all stats")
    func resetClears() throws {
        let config = try FECConfiguration(columns: 2, rows: 1, layout: .even)
        var decoder = FECDecoder(configuration: config)

        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(0), payload: [0x01], timestamp: 10)
        decoder.reset()
        #expect(decoder.totalRecovered == 0)
        #expect(decoder.totalIrrecoverable == 0)
    }

    // MARK: - Mixed payload sizes

    @Test("Recovery with different payload sizes trims correctly")
    func mixedPayloadSizes() throws {
        let config = try FECConfiguration(columns: 2, rows: 1, layout: .even)
        var decoder = FECDecoder(configuration: config)

        let sources: [TestSource] = [
            TestSource(seq: 0, payload: [0xAA, 0xBB, 0xCC], timestamp: 10),
            TestSource(seq: 1, payload: [0xDD, 0xEE], timestamp: 20)
        ]

        // Lose packet 1
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(0), payload: [0xAA, 0xBB, 0xCC], timestamp: 10)
        decoder.receiveFECPacket(buildRowFEC(sources: sources, row: 0, baseSeq: 0))

        let result = decoder.attemptRecovery()
        if case .recovered(let packets) = result {
            #expect(packets[0].payload == [0xDD, 0xEE])
        } else {
            Issue.record("Expected recovered")
        }
    }
}
