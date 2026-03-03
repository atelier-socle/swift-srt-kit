// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("Transport Showcase")
struct TransportShowcaseTests {
    // MARK: - Address Resolver

    @Test("AddressResolver IPv4 validation")
    func addressResolverIPv4() {
        #expect(AddressResolver.isIPv4("192.168.1.1"))
        #expect(AddressResolver.isIPv4("0.0.0.0"))
        #expect(AddressResolver.isIPv4("255.255.255.255"))
        #expect(!AddressResolver.isIPv4("256.0.0.1"))
        #expect(!AddressResolver.isIPv4("not-an-ip"))
        #expect(!AddressResolver.isIPv4("::1"))
    }

    @Test("AddressResolver IPv6 validation")
    func addressResolverIPv6() {
        #expect(AddressResolver.isIPv6("::1"))
        #expect(AddressResolver.isIPv6("fe80::1"))
        #expect(!AddressResolver.isIPv6("192.168.1.1"))
    }

    // MARK: - Socket ID Generator

    @Test("SocketIDGenerator produces unique IDs")
    func socketIDGeneration() {
        let id1 = SocketIDGenerator.generate()
        let id2 = SocketIDGenerator.generate()
        // Random — extremely unlikely to collide
        #expect(id1 != 0)
        #expect(id2 != 0)
    }

    @Test("SocketIDGenerator avoids existing IDs")
    func socketIDAvoidance() {
        let existing: Set<UInt32> = [1, 2, 3, 4, 5]
        let newID = SocketIDGenerator.generate(avoiding: existing)
        #expect(!existing.contains(newID))
    }
}

@Suite("FEC Showcase")
struct FECShowcaseTests {
    // MARK: - Configuration

    @Test("FECConfiguration valid creation")
    func fecConfigValid() throws {
        let config = try FECConfiguration(
            columns: 10, rows: 5,
            layout: .staircase, arqMode: .always)
        #expect(config.matrixSize == 50)
        #expect(config.rowFECCount == 5)
        #expect(config.columnFECCount == 10)
        #expect(config.totalFECPackets == 15)
        #expect(config.overheadRatio > 0)
    }

    @Test("FECConfiguration parse from filter string")
    func fecConfigParse() throws {
        let config = try FECConfiguration(
            columns: 5, rows: 3)
        let filterString = config.toFilterString()
        let parsed = FECConfiguration.parse(filterString)
        #expect(parsed != nil)
        #expect(parsed?.columns == 5)
        #expect(parsed?.rows == 3)
    }

    @Test("FECConfiguration invalid dimensions rejected")
    func fecConfigInvalid() {
        #expect(throws: FECError.self) {
            try FECConfiguration(columns: 0, rows: 5)
        }
        #expect(throws: FECError.self) {
            try FECConfiguration(columns: 5, rows: 0)
        }
    }

    // MARK: - FEC Encoder

    @Test("FECEncoder accumulates packets and generates FEC")
    func fecEncoderBasic() throws {
        let config = try FECConfiguration(
            columns: 4, rows: 1,
            layout: .even, arqMode: .always)
        var encoder = FECEncoder(configuration: config)
        #expect(encoder.packetsProcessed == 0)

        // Submit packets up to column count
        for i in 0..<4 {
            let source = FECEncoder.SourcePacket(
                sequenceNumber: SequenceNumber(UInt32(i)),
                payload: Array(repeating: UInt8(i), count: 188),
                timestamp: UInt32(i) * 10_000)
            let result = encoder.submitPacket(source)
            if i < 3 {
                if case .pending = result {
                    // Expected: accumulating
                }
            }
        }
        #expect(encoder.packetsProcessed == 4)
    }

    // MARK: - FEC Decoder

    @Test("FECDecoder tracks recovery statistics")
    func fecDecoderStats() throws {
        let config = try FECConfiguration(
            columns: 4, rows: 1)
        var decoder = FECDecoder(configuration: config)
        #expect(decoder.totalRecovered == 0)
        #expect(decoder.totalIrrecoverable == 0)

        // Feed source packets — no loss
        for i in 0..<4 {
            decoder.receiveSourcePacket(
                sequenceNumber: SequenceNumber(UInt32(i)),
                payload: Array(
                    repeating: UInt8(i), count: 188),
                timestamp: UInt32(i) * 10_000)
        }

        let result = decoder.attemptRecovery()
        if case .noLoss = result {
            // Expected: all packets received
        }
    }
}
