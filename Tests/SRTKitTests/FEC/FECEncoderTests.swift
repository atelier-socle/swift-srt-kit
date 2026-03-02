// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("FECEncoder Tests")
struct FECEncoderTests {
    private func makePacket(
        seq: UInt32, payload: [UInt8], timestamp: UInt32 = 0
    ) -> FECEncoder.SourcePacket {
        FECEncoder.SourcePacket(
            sequenceNumber: SequenceNumber(seq),
            payload: payload,
            timestamp: timestamp
        )
    }

    // MARK: - Row FEC generation

    @Test("Submit cols packets emits row FEC")
    func rowFECEmitted() throws {
        let config = try FECConfiguration(columns: 3, rows: 2)
        var encoder = FECEncoder(configuration: config)

        let r0 = encoder.submitPacket(makePacket(seq: 0, payload: [0x01]))
        let r1 = encoder.submitPacket(makePacket(seq: 1, payload: [0x02]))
        if case .pending = r0 {} else { Issue.record("Expected pending") }
        if case .pending = r1 {} else { Issue.record("Expected pending") }

        let r2 = encoder.submitPacket(makePacket(seq: 2, payload: [0x04]))
        if case .fecReady(let packets) = r2 {
            #expect(packets.count == 1)
            #expect(packets[0].direction == .row)
            #expect(packets[0].groupSize == 3)
        } else {
            Issue.record("Expected fecReady")
        }
    }

    @Test("Row FEC payload is XOR of source payloads")
    func rowFECPayloadXOR() throws {
        let config = try FECConfiguration(columns: 3, rows: 1)
        var encoder = FECEncoder(configuration: config)

        _ = encoder.submitPacket(makePacket(seq: 0, payload: [0xFF, 0x00]))
        _ = encoder.submitPacket(makePacket(seq: 1, payload: [0x0F, 0xF0]))
        let result = encoder.submitPacket(makePacket(seq: 2, payload: [0xF0, 0x0F]))

        if case .fecReady(let packets) = result {
            // 0xFF ^ 0x0F ^ 0xF0 = 0x00, 0x00 ^ 0xF0 ^ 0x0F = 0xFF
            #expect(packets[0].payloadXOR == [0x00, 0xFF])
        } else {
            Issue.record("Expected fecReady")
        }
    }

    @Test("Row FEC lengthRecovery is XOR of lengths")
    func rowFECLengthRecovery() throws {
        let config = try FECConfiguration(columns: 2, rows: 1)
        var encoder = FECEncoder(configuration: config)

        _ = encoder.submitPacket(makePacket(seq: 0, payload: [0x01, 0x02, 0x03]))  // len 3
        let result = encoder.submitPacket(makePacket(seq: 1, payload: [0x04, 0x05]))  // len 2

        if case .fecReady(let packets) = result {
            #expect(packets[0].lengthRecovery == 3 ^ 2)  // = 1
        } else {
            Issue.record("Expected fecReady")
        }
    }

    @Test("Row FEC timestampRecovery is XOR of timestamps")
    func rowFECTimestampRecovery() throws {
        let config = try FECConfiguration(columns: 2, rows: 1)
        var encoder = FECEncoder(configuration: config)

        _ = encoder.submitPacket(makePacket(seq: 0, payload: [0x01], timestamp: 1000))
        let result = encoder.submitPacket(
            makePacket(seq: 1, payload: [0x02], timestamp: 2000))

        if case .fecReady(let packets) = result {
            #expect(packets[0].timestampRecovery == 1000 ^ 2000)
        } else {
            Issue.record("Expected fecReady")
        }
    }

    @Test("Less than cols packets returns pending")
    func pendingBeforeComplete() throws {
        let config = try FECConfiguration(columns: 5, rows: 1)
        var encoder = FECEncoder(configuration: config)

        for i in 0..<4 {
            let result = encoder.submitPacket(
                makePacket(seq: UInt32(i), payload: [UInt8(i)]))
            if case .pending = result {
            } else {
                Issue.record("Expected pending at packet \(i)")
            }
        }
    }

    @Test("Multiple rows emit one FEC per row")
    func multipleRowsFEC() throws {
        let config = try FECConfiguration(columns: 2, rows: 3)
        var encoder = FECEncoder(configuration: config)
        var rowFECCount = 0

        for i: UInt32 in 0..<6 {
            let result = encoder.submitPacket(
                makePacket(seq: i, payload: [UInt8(i)]))
            if case .fecReady(let packets) = result {
                rowFECCount += packets.filter { $0.direction == .row }.count
            }
        }
        // 3 rows complete → 3 row FECs + column FECs at end of matrix
        #expect(rowFECCount == 3)
    }

    // MARK: - Column FEC generation

    @Test("Full matrix emits column FECs")
    func columnFECAfterMatrix() throws {
        let config = try FECConfiguration(columns: 2, rows: 3, layout: .even)
        var encoder = FECEncoder(configuration: config)
        var colFECPackets: [FECPacket] = []

        for i: UInt32 in 0..<6 {
            let result = encoder.submitPacket(
                makePacket(seq: i, payload: [UInt8(i)]))
            if case .fecReady(let packets) = result {
                colFECPackets.append(
                    contentsOf: packets.filter { $0.direction == .column })
            }
        }
        // 2 columns → 2 column FECs
        #expect(colFECPackets.count == 2)
    }

    @Test("Column FEC groups correct packets in even layout")
    func columnGroupingEven() throws {
        let config = try FECConfiguration(columns: 2, rows: 2, layout: .even)
        var encoder = FECEncoder(configuration: config)

        // Matrix: [0,1] [2,3]
        // Col 0: packets 0,2. Col 1: packets 1,3
        let payloads: [[UInt8]] = [[0x10], [0x20], [0x30], [0x40]]
        var colFECPackets: [FECPacket] = []

        for i: UInt32 in 0..<4 {
            let result = encoder.submitPacket(
                makePacket(seq: i, payload: payloads[Int(i)]))
            if case .fecReady(let packets) = result {
                colFECPackets.append(
                    contentsOf: packets.filter { $0.direction == .column })
            }
        }

        #expect(colFECPackets.count == 2)
        // Col 0: 0x10 ^ 0x30 = 0x20
        let col0 = colFECPackets.first { $0.groupIndex == 0 }
        #expect(col0?.payloadXOR == [0x20])
        // Col 1: 0x20 ^ 0x40 = 0x60
        let col1 = colFECPackets.first { $0.groupIndex == 1 }
        #expect(col1?.payloadXOR == [0x60])
    }

    // MARK: - Stats

    @Test("packetsProcessed tracks source packets")
    func packetsProcessed() throws {
        let config = try FECConfiguration(columns: 3, rows: 1)
        var encoder = FECEncoder(configuration: config)
        for i: UInt32 in 0..<3 {
            _ = encoder.submitPacket(makePacket(seq: i, payload: [0x01]))
        }
        #expect(encoder.packetsProcessed == 3)
    }

    @Test("fecPacketsGenerated tracks total FEC")
    func fecPacketsGenerated() throws {
        let config = try FECConfiguration(columns: 2, rows: 2, layout: .even)
        var encoder = FECEncoder(configuration: config)
        for i: UInt32 in 0..<4 {
            _ = encoder.submitPacket(makePacket(seq: i, payload: [UInt8(i)]))
        }
        // 2 row FECs + 2 column FECs = 4
        #expect(encoder.fecPacketsGenerated == 4)
    }

    // MARK: - Flush

    @Test("Flush incomplete row emits partial FEC")
    func flushIncomplete() throws {
        let config = try FECConfiguration(columns: 4, rows: 1)
        var encoder = FECEncoder(configuration: config)
        _ = encoder.submitPacket(makePacket(seq: 0, payload: [0xFF]))
        _ = encoder.submitPacket(makePacket(seq: 1, payload: [0x0F]))
        let flushed = encoder.flush()
        #expect(flushed.count == 1)
        #expect(flushed[0].groupSize == 2)
    }

    @Test("Flush with no pending returns empty")
    func flushEmpty() throws {
        let config = try FECConfiguration(columns: 3, rows: 1)
        var encoder = FECEncoder(configuration: config)
        let flushed = encoder.flush()
        #expect(flushed.isEmpty)
    }

    // MARK: - Reset

    @Test("Reset clears all state")
    func resetState() throws {
        let config = try FECConfiguration(columns: 2, rows: 1)
        var encoder = FECEncoder(configuration: config)
        _ = encoder.submitPacket(makePacket(seq: 0, payload: [0x01]))
        encoder.reset()
        #expect(encoder.packetsProcessed == 0)
        #expect(encoder.fecPacketsGenerated == 0)
    }

    // MARK: - Staircase layout

    @Test("Staircase layout offsets column groups")
    func staircaseColumnOffset() throws {
        let config = try FECConfiguration(columns: 3, rows: 2, layout: .staircase)
        var encoder = FECEncoder(configuration: config)
        var colFECPackets: [FECPacket] = []

        // Matrix: row0=[0,1,2] row1=[3,4,5]
        // Even: col0=[0,3], col1=[1,4], col2=[2,5]
        // Staircase: col_group = (col + row) % 3
        //   row0: (0+0)%3=0, (1+0)%3=1, (2+0)%3=2  → same as even
        //   row1: (0+1)%3=1, (1+1)%3=2, (2+1)%3=0  → shifted
        // So staircase cols: col0=[0,5], col1=[1,3], col2=[2,4]
        let payloads: [[UInt8]] = [[0x10], [0x20], [0x30], [0x40], [0x50], [0x60]]
        for i: UInt32 in 0..<6 {
            let result = encoder.submitPacket(
                makePacket(seq: i, payload: payloads[Int(i)]))
            if case .fecReady(let packets) = result {
                colFECPackets.append(
                    contentsOf: packets.filter { $0.direction == .column })
            }
        }

        #expect(colFECPackets.count == 3)
        // col0: packets 0,5 → 0x10 ^ 0x60 = 0x70
        let col0 = colFECPackets.first { $0.groupIndex == 0 }
        #expect(col0?.payloadXOR == [0x70])
    }

    @Test("Row FEC base sequence is row start")
    func rowFECBaseSequence() throws {
        let config = try FECConfiguration(columns: 3, rows: 2)
        var encoder = FECEncoder(configuration: config)
        var rowFECs: [FECPacket] = []
        for i: UInt32 in 0..<6 {
            let result = encoder.submitPacket(
                makePacket(seq: 10 + i, payload: [UInt8(i)]))
            if case .fecReady(let packets) = result {
                rowFECs.append(contentsOf: packets.filter { $0.direction == .row })
            }
        }
        #expect(rowFECs.count == 2)
        #expect(rowFECs[0].baseSequenceNumber == SequenceNumber(10))
        #expect(rowFECs[1].baseSequenceNumber == SequenceNumber(13))
    }
}
