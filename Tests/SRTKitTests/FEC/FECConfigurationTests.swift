// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("FECConfiguration Tests")
struct FECConfigurationTests {
    // MARK: - Initialization

    @Test("Valid config cols=10 rows=5 succeeds")
    func validConfig() throws {
        let config = try FECConfiguration(columns: 10, rows: 5)
        #expect(config.columns == 10)
        #expect(config.rows == 5)
    }

    @Test("cols=0 throws columnsOutOfRange")
    func colsZero() {
        #expect(throws: FECError.columnsOutOfRange(got: 0)) {
            try FECConfiguration(columns: 0, rows: 5)
        }
    }

    @Test("cols=257 throws columnsOutOfRange")
    func colsTooHigh() {
        #expect(throws: FECError.columnsOutOfRange(got: 257)) {
            try FECConfiguration(columns: 257, rows: 5)
        }
    }

    @Test("rows=0 throws rowsOutOfRange")
    func rowsZero() {
        #expect(throws: FECError.rowsOutOfRange(got: 0)) {
            try FECConfiguration(columns: 10, rows: 0)
        }
    }

    @Test("rows=257 throws rowsOutOfRange")
    func rowsTooHigh() {
        #expect(throws: FECError.rowsOutOfRange(got: 257)) {
            try FECConfiguration(columns: 10, rows: 257)
        }
    }

    @Test("matrixSize = cols × rows")
    func matrixSize() throws {
        let config = try FECConfiguration(columns: 10, rows: 5)
        #expect(config.matrixSize == 50)
    }

    @Test("totalFECPackets = rows + cols")
    func totalFECPackets() throws {
        let config = try FECConfiguration(columns: 10, rows: 5)
        #expect(config.totalFECPackets == 15)
    }

    @Test("overheadRatio for cols=10 rows=5 is 0.3")
    func overheadRatio() throws {
        let config = try FECConfiguration(columns: 10, rows: 5)
        #expect(config.overheadRatio == 0.3)
    }

    @Test("rowFECCount and columnFECCount")
    func fecCounts() throws {
        let config = try FECConfiguration(columns: 10, rows: 5)
        #expect(config.rowFECCount == 5)
        #expect(config.columnFECCount == 10)
    }

    // MARK: - Filter string parsing

    @Test("Parse full filter string with staircase")
    func parseFullStaircase() {
        let config = FECConfiguration.parse(
            "fec,cols:10,rows:5,layout:staircase,arq:always")
        #expect(config?.columns == 10)
        #expect(config?.rows == 5)
        #expect(config?.layout == .staircase)
        #expect(config?.arqMode == .always)
    }

    @Test("Parse filter string with even layout and arq never")
    func parseEvenNever() {
        let config = FECConfiguration.parse(
            "fec,cols:4,rows:3,layout:even,arq:never")
        #expect(config?.columns == 4)
        #expect(config?.rows == 3)
        #expect(config?.layout == .even)
        #expect(config?.arqMode == .never)
    }

    @Test("Parse minimal filter string uses defaults")
    func parseMinimal() {
        let config = FECConfiguration.parse("fec,cols:10,rows:5")
        #expect(config?.layout == .staircase)
        #expect(config?.arqMode == .always)
    }

    @Test("Parse with arq onreq")
    func parseOnreq() {
        let config = FECConfiguration.parse(
            "fec,cols:4,rows:3,arq:onreq")
        #expect(config?.arqMode == .onreq)
    }

    @Test("Parse invalid string returns nil")
    func parseInvalid() {
        #expect(FECConfiguration.parse("not_fec,cols:10") == nil)
    }

    @Test("Parse non-FEC filter returns nil")
    func parseNonFEC() {
        #expect(FECConfiguration.parse("other,cols:10,rows:5") == nil)
    }

    @Test("toFilterString roundtrip")
    func filterStringRoundtrip() throws {
        let config = try FECConfiguration(
            columns: 10, rows: 5, layout: .staircase, arqMode: .always)
        let s = config.toFilterString()
        let parsed = FECConfiguration.parse(s)
        #expect(parsed == config)
    }

    // MARK: - Equatable

    @Test("Same config is equal")
    func equalConfigs() throws {
        let a = try FECConfiguration(columns: 10, rows: 5)
        let b = try FECConfiguration(columns: 10, rows: 5)
        #expect(a == b)
    }

    @Test("Different cols not equal")
    func differentCols() throws {
        let a = try FECConfiguration(columns: 10, rows: 5)
        let b = try FECConfiguration(columns: 8, rows: 5)
        #expect(a != b)
    }

    // MARK: - Edge cases

    @Test("Boundary cols=1 rows=1 succeeds")
    func minBoundary() throws {
        let config = try FECConfiguration(columns: 1, rows: 1)
        #expect(config.matrixSize == 1)
    }

    @Test("Boundary cols=256 rows=256 succeeds")
    func maxBoundary() throws {
        let config = try FECConfiguration(columns: 256, rows: 256)
        #expect(config.matrixSize == 65536)
    }
}
