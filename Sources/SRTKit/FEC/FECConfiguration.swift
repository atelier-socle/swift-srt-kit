// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// FEC matrix configuration.
///
/// Defines the dimensions, layout, and ARQ interaction mode
/// for forward error correction.
public struct FECConfiguration: Sendable, Equatable {
    /// FEC matrix layout mode.
    public enum Layout: String, Sendable, CaseIterable {
        /// Row groups align with column groups (simple).
        case even
        /// Row groups offset to spread burst errors across columns.
        case staircase
    }

    /// ARQ interaction mode with FEC.
    public enum ARQMode: String, Sendable, CaseIterable {
        /// FEC + ARQ both active (default).
        case always
        /// FEC first, ARQ only if FEC fails.
        case onreq
        /// FEC only, no retransmission.
        case never
    }

    /// Number of columns (packets per row). Range: 1–256.
    public let columns: Int
    /// Number of rows (packets per column). Range: 1–256.
    public let rows: Int
    /// Matrix layout mode.
    public let layout: Layout
    /// ARQ interaction mode.
    public let arqMode: ARQMode

    /// Total source packets per FEC matrix.
    public var matrixSize: Int { columns * rows }

    /// Number of row FEC packets per matrix.
    public var rowFECCount: Int { rows }

    /// Number of column FEC packets per matrix.
    public var columnFECCount: Int { columns }

    /// Total FEC packets per matrix (row + column).
    public var totalFECPackets: Int { rows + columns }

    /// FEC overhead ratio (FEC packets / source packets).
    public var overheadRatio: Double {
        Double(totalFECPackets) / Double(matrixSize)
    }

    /// Create a FEC configuration.
    ///
    /// - Parameters:
    ///   - columns: Number of columns (packets per row). Must be 1–256.
    ///   - rows: Number of rows (packets per column). Must be 1–256.
    ///   - layout: Matrix layout mode.
    ///   - arqMode: ARQ interaction mode.
    /// - Throws: `FECError` if columns or rows are out of range.
    public init(
        columns: Int,
        rows: Int,
        layout: Layout = .staircase,
        arqMode: ARQMode = .always
    ) throws {
        guard columns >= 1, columns <= 256 else {
            throw FECError.columnsOutOfRange(got: columns)
        }
        guard rows >= 1, rows <= 256 else {
            throw FECError.rowsOutOfRange(got: rows)
        }
        self.columns = columns
        self.rows = rows
        self.layout = layout
        self.arqMode = arqMode
    }

    /// Parse from SRTO_PACKETFILTER option string.
    ///
    /// Format: `"fec,cols:<N>,rows:<N>,layout:<staircase|even>,arq:<never|onreq|always>"`
    /// - Parameter filterString: The filter string to parse.
    /// - Returns: Parsed configuration, or nil if not a FEC filter string.
    public static func parse(_ filterString: String) -> FECConfiguration? {
        let parts = filterString.split(separator: ",")
        guard !parts.isEmpty, parts[0] == "fec" else { return nil }

        var cols: Int?
        var rows: Int?
        var layout: Layout = .staircase
        var arqMode: ARQMode = .always

        for part in parts.dropFirst() {
            guard let result = parseKeyValue(part) else { return nil }
            switch result {
            case .cols(let v): cols = v
            case .rows(let v): rows = v
            case .layout(let v): layout = v
            case .arq(let v): arqMode = v
            case .unknown: break
            }
        }

        guard let c = cols, let r = rows else { return nil }
        return try? FECConfiguration(columns: c, rows: r, layout: layout, arqMode: arqMode)
    }

    /// Parsed key-value from a filter string component.
    private enum ParsedValue {
        case cols(Int)
        case rows(Int)
        case layout(Layout)
        case arq(ARQMode)
        case unknown
    }

    /// Parse a single key:value pair from the filter string.
    private static func parseKeyValue(_ part: Substring) -> ParsedValue? {
        let kv = part.split(separator: ":", maxSplits: 1)
        guard kv.count == 2 else { return .unknown }
        let key = String(kv[0])
        let value = String(kv[1])
        switch key {
        case "cols": return .cols(Int(value) ?? 0)
        case "rows": return .rows(Int(value) ?? 0)
        case "layout":
            guard let v = Layout(rawValue: value) else { return nil }
            return .layout(v)
        case "arq":
            guard let v = ARQMode(rawValue: value) else { return nil }
            return .arq(v)
        default: return .unknown
        }
    }

    /// Generate the SRTO_PACKETFILTER option string.
    ///
    /// - Returns: The filter string representation.
    public func toFilterString() -> String {
        "fec,cols:\(columns),rows:\(rows),layout:\(layout.rawValue),arq:\(arqMode.rawValue)"
    }
}
