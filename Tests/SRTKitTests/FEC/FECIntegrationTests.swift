// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("FEC Integration Tests")
struct FECIntegrationTests {
    /// A source packet descriptor for test helpers.
    private struct TestSource {
        let seq: UInt32
        let payload: [UInt8]
        let timestamp: UInt32
    }

    /// Encode all source packets and collect FEC packets.
    private func encodeAll(
        encoder: inout FECEncoder,
        sources: [TestSource]
    ) -> [FECPacket] {
        var fecPackets: [FECPacket] = []
        for src in sources {
            let result = encoder.submitPacket(
                FECEncoder.SourcePacket(
                    sequenceNumber: SequenceNumber(src.seq),
                    payload: src.payload,
                    timestamp: src.timestamp
                ))
            if case .fecReady(let packets) = result {
                fecPackets.append(contentsOf: packets)
            }
        }
        return fecPackets
    }

    // MARK: - Encode → Decode roundtrip

    @Test("Encode 10 packets, lose 1 per row, all recovered")
    func encodeDecodeRowRecovery() throws {
        let config = try FECConfiguration(columns: 5, rows: 2, layout: .even)
        var encoder = FECEncoder(configuration: config)

        var sources: [TestSource] = []
        for i: UInt32 in 0..<10 {
            sources.append(TestSource(seq: i, payload: [UInt8(i), UInt8(i &+ 1)], timestamp: i * 1000))
        }

        let fecPackets = encodeAll(encoder: &encoder, sources: sources)
        let rowFECs = fecPackets.filter { $0.direction == .row }
        #expect(rowFECs.count == 2)

        // Decode: lose packet 2 (row 0) and packet 7 (row 1)
        var decoder = FECDecoder(configuration: config)
        for src in sources where src.seq != 2 && src.seq != 7 {
            decoder.receiveSourcePacket(
                sequenceNumber: SequenceNumber(src.seq),
                payload: src.payload,
                timestamp: src.timestamp)
        }
        for fec in rowFECs {
            decoder.receiveFECPacket(fec)
        }

        let result = decoder.attemptRecovery()
        if case .recovered(let packets) = result {
            #expect(packets.count == 2)
            let seqs = Set(packets.map { $0.sequenceNumber.value })
            #expect(seqs.contains(2))
            #expect(seqs.contains(7))
            let pkt2 = packets.first { $0.sequenceNumber == SequenceNumber(2) }
            #expect(pkt2?.payload == [2, 3])
        } else {
            Issue.record("Expected recovered")
        }
    }

    @Test("Encode → decode with 0 losses is noLoss")
    func encodeDecodeNoLoss() throws {
        let config = try FECConfiguration(columns: 3, rows: 1, layout: .even)
        var encoder = FECEncoder(configuration: config)

        let sources: [TestSource] = [
            TestSource(seq: 0, payload: [0x01], timestamp: 10),
            TestSource(seq: 1, payload: [0x02], timestamp: 20),
            TestSource(seq: 2, payload: [0x03], timestamp: 30)
        ]
        let fecPackets = encodeAll(encoder: &encoder, sources: sources)

        var decoder = FECDecoder(configuration: config)
        for src in sources {
            decoder.receiveSourcePacket(
                sequenceNumber: SequenceNumber(src.seq),
                payload: src.payload,
                timestamp: src.timestamp)
        }
        for fec in fecPackets {
            decoder.receiveFECPacket(fec)
        }

        let result = decoder.attemptRecovery()
        if case .noLoss = result {
        } else {
            Issue.record("Expected noLoss")
        }
    }

    @Test("Encode → decode with column loss recovered via column FEC")
    func columnLossRecovery() throws {
        let config = try FECConfiguration(columns: 2, rows: 2, layout: .even)
        var encoder = FECEncoder(configuration: config)

        // Matrix: [0,1][2,3]. Col 0: [0,2], Col 1: [1,3]
        let sources: [TestSource] = [
            TestSource(seq: 0, payload: [0x10], timestamp: 100),
            TestSource(seq: 1, payload: [0x20], timestamp: 200),
            TestSource(seq: 2, payload: [0x30], timestamp: 300),
            TestSource(seq: 3, payload: [0x40], timestamp: 400)
        ]
        let fecPackets = encodeAll(encoder: &encoder, sources: sources)
        let colFECs = fecPackets.filter { $0.direction == .column }
        #expect(colFECs.count == 2)

        // Lose packet 0 → column 0 FEC can recover
        var decoder = FECDecoder(configuration: config)
        for src in sources where src.seq != 0 {
            decoder.receiveSourcePacket(
                sequenceNumber: SequenceNumber(src.seq),
                payload: src.payload,
                timestamp: src.timestamp)
        }
        for fec in colFECs {
            decoder.receiveFECPacket(fec)
        }

        let result = decoder.attemptRecovery()
        if case .recovered(let packets) = result {
            #expect(packets[0].sequenceNumber == SequenceNumber(0))
            #expect(packets[0].payload == [0x10])
        } else {
            Issue.record("Expected recovered")
        }
    }

    // MARK: - Different configurations

    @Test("cols=4 rows=3 even layout works")
    func config4x3Even() throws {
        let config = try FECConfiguration(columns: 4, rows: 3, layout: .even)
        var encoder = FECEncoder(configuration: config)

        var sources: [TestSource] = []
        for i: UInt32 in 0..<12 {
            sources.append(TestSource(seq: i, payload: [UInt8(i)], timestamp: i * 100))
        }
        let fecPackets = encodeAll(encoder: &encoder, sources: sources)
        let rowFECs = fecPackets.filter { $0.direction == .row }
        #expect(rowFECs.count == 3)

        // Lose packet 5 (row 1, col 1)
        var decoder = FECDecoder(configuration: config)
        for src in sources where src.seq != 5 {
            decoder.receiveSourcePacket(
                sequenceNumber: SequenceNumber(src.seq),
                payload: src.payload,
                timestamp: src.timestamp)
        }
        for fec in rowFECs {
            decoder.receiveFECPacket(fec)
        }

        let result = decoder.attemptRecovery()
        if case .recovered(let packets) = result {
            #expect(packets[0].payload == [5])
        } else {
            Issue.record("Expected recovered")
        }
    }

    @Test("cols=20 rows=1 row-only recovers single loss")
    func rowOnlyConfig() throws {
        let config = try FECConfiguration(columns: 20, rows: 1, layout: .even)
        var encoder = FECEncoder(configuration: config)

        var sources: [TestSource] = []
        for i: UInt32 in 0..<20 {
            sources.append(
                TestSource(seq: i, payload: [UInt8(i), UInt8(i &+ 10)], timestamp: i * 50))
        }
        let fecPackets = encodeAll(encoder: &encoder, sources: sources)

        // Lose packet 13
        var decoder = FECDecoder(configuration: config)
        for src in sources where src.seq != 13 {
            decoder.receiveSourcePacket(
                sequenceNumber: SequenceNumber(src.seq),
                payload: src.payload,
                timestamp: src.timestamp)
        }
        for fec in fecPackets {
            decoder.receiveFECPacket(fec)
        }

        let result = decoder.attemptRecovery()
        if case .recovered(let packets) = result {
            #expect(packets[0].sequenceNumber == SequenceNumber(13))
            #expect(packets[0].payload == [13, 23])
        } else {
            Issue.record("Expected recovered")
        }
    }

    // MARK: - ARQ interaction

    @Test("ARQ mode always is default")
    func arqAlwaysDefault() throws {
        let config = try FECConfiguration(columns: 5, rows: 2)
        #expect(config.arqMode == .always)
    }

    @Test("ARQ mode never configured correctly")
    func arqNever() throws {
        let config = try FECConfiguration(
            columns: 5, rows: 2, arqMode: .never)
        #expect(config.arqMode == .never)
    }

    @Test("ARQ mode onreq configured correctly")
    func arqOnreq() throws {
        let config = try FECConfiguration(
            columns: 5, rows: 2, arqMode: .onreq)
        #expect(config.arqMode == .onreq)
    }

    // MARK: - Large payloads

    @Test("1316-byte MPEG-TS payloads encode and recover correctly")
    func largeMPEGTSPayload() throws {
        let config = try FECConfiguration(columns: 3, rows: 1, layout: .even)
        var encoder = FECEncoder(configuration: config)

        let payload0 = [UInt8](repeating: 0x47, count: 1316)
        var payload1 = [UInt8](repeating: 0x00, count: 1316)
        payload1[0] = 0x47
        payload1[1] = 0xFF
        let payload2 = [UInt8](repeating: 0xAA, count: 1316)

        let sources: [TestSource] = [
            TestSource(seq: 0, payload: payload0, timestamp: 1000),
            TestSource(seq: 1, payload: payload1, timestamp: 2000),
            TestSource(seq: 2, payload: payload2, timestamp: 3000)
        ]
        let fecPackets = encodeAll(encoder: &encoder, sources: sources)

        // Lose packet 1
        var decoder = FECDecoder(configuration: config)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(0), payload: payload0, timestamp: 1000)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(2), payload: payload2, timestamp: 3000)
        for fec in fecPackets {
            decoder.receiveFECPacket(fec)
        }

        let result = decoder.attemptRecovery()
        if case .recovered(let packets) = result {
            #expect(packets[0].payload == payload1)
        } else {
            Issue.record("Expected recovered")
        }
    }

    @Test("Mixed payload sizes within group handled correctly")
    func mixedPayloadSizes() throws {
        let config = try FECConfiguration(columns: 3, rows: 1, layout: .even)
        var encoder = FECEncoder(configuration: config)

        let sources: [TestSource] = [
            TestSource(seq: 0, payload: [0x01, 0x02, 0x03, 0x04], timestamp: 10),
            TestSource(seq: 1, payload: [0xAA, 0xBB], timestamp: 20),
            TestSource(seq: 2, payload: [0xFF], timestamp: 30)
        ]
        let fecPackets = encodeAll(encoder: &encoder, sources: sources)

        // Lose packet 1 (2 bytes)
        var decoder = FECDecoder(configuration: config)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(0),
            payload: [0x01, 0x02, 0x03, 0x04], timestamp: 10)
        decoder.receiveSourcePacket(
            sequenceNumber: SequenceNumber(2), payload: [0xFF], timestamp: 30)
        for fec in fecPackets {
            decoder.receiveFECPacket(fec)
        }

        let result = decoder.attemptRecovery()
        if case .recovered(let packets) = result {
            #expect(packets[0].payload == [0xAA, 0xBB])
        } else {
            Issue.record("Expected recovered")
        }
    }

    // MARK: - FECError descriptions

    @Test("FECError descriptions are meaningful")
    func errorDescriptions() {
        let errors: [FECError] = [
            .columnsOutOfRange(got: 0),
            .rowsOutOfRange(got: 300),
            .invalidFilterString("bad"),
            .unknownLayout("foo"),
            .unknownARQMode("bar")
        ]
        for err in errors {
            #expect(!err.description.isEmpty)
        }
    }

    @Test("FECDirection equatable")
    func directionEquatable() {
        #expect(FECDirection.row == FECDirection.row)
        #expect(FECDirection.column == FECDirection.column)
        #expect(FECDirection.row != FECDirection.column)
    }
}
