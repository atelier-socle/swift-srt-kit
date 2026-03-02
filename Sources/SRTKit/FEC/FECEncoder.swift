// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Generates FEC packets from groups of source packets.
///
/// The encoder maintains state for the current FEC matrix,
/// collecting source packets and generating row/column FEC
/// packets as groups complete.
public struct FECEncoder: Sendable {
    /// A source packet submitted to the encoder.
    public struct SourcePacket: Sendable {
        /// The packet's sequence number.
        public let sequenceNumber: SequenceNumber
        /// The packet payload.
        public let payload: [UInt8]
        /// The packet timestamp.
        public let timestamp: UInt32
        /// The message number.
        public let messageNumber: UInt32

        /// Creates a source packet.
        ///
        /// - Parameters:
        ///   - sequenceNumber: The packet's sequence number.
        ///   - payload: The packet payload.
        ///   - timestamp: The packet timestamp.
        ///   - messageNumber: The message number.
        public init(
            sequenceNumber: SequenceNumber,
            payload: [UInt8],
            timestamp: UInt32,
            messageNumber: UInt32 = 0
        ) {
            self.sequenceNumber = sequenceNumber
            self.payload = payload
            self.timestamp = timestamp
            self.messageNumber = messageNumber
        }
    }

    /// Result of submitting a source packet.
    public enum EncodeResult: Sendable {
        /// No FEC packets ready yet (group not complete).
        case pending
        /// One or more FEC packets are ready.
        case fecReady(packets: [FECPacket])
    }

    /// The FEC configuration.
    public let configuration: FECConfiguration

    /// Running XOR accumulator for each row.
    private var rowAccumulators: [RowAccumulator]

    /// Running XOR accumulator for each column.
    private var columnAccumulators: [ColumnAccumulator]

    /// Current position within the matrix (0-based linear index).
    private var matrixPosition: Int = 0

    /// Base sequence number of the current matrix.
    private var matrixBaseSequence: SequenceNumber?

    /// Number of source packets processed.
    public private(set) var packetsProcessed: Int = 0

    /// Number of FEC packets generated.
    public private(set) var fecPacketsGenerated: Int = 0

    /// Creates a FEC encoder.
    ///
    /// - Parameter configuration: The FEC configuration.
    public init(configuration: FECConfiguration) {
        self.configuration = configuration
        self.rowAccumulators = (0..<configuration.rows).map { _ in RowAccumulator() }
        self.columnAccumulators = (0..<configuration.columns).map { _ in ColumnAccumulator() }
    }

    /// Submit a source packet for FEC processing.
    ///
    /// When enough packets accumulate to complete a row or column
    /// group, the corresponding FEC packet(s) are generated.
    /// - Parameter packet: The source packet to process.
    /// - Returns: FEC packets if any groups completed.
    public mutating func submitPacket(_ packet: SourcePacket) -> EncodeResult {
        if matrixBaseSequence == nil {
            matrixBaseSequence = packet.sequenceNumber
        }

        let row = matrixPosition / configuration.columns
        let col = matrixPosition % configuration.columns
        let colGroupIndex = columnIndex(row: row, col: col)

        // Accumulate into row
        rowAccumulators[row].accumulate(packet)

        // Accumulate into column
        columnAccumulators[colGroupIndex].accumulate(packet)

        packetsProcessed += 1
        matrixPosition += 1

        var fecPackets: [FECPacket] = []

        // Check if row is complete
        if rowAccumulators[row].count == configuration.columns {
            let base = matrixBaseSequence ?? SequenceNumber(0)
            let rowBase = base + Int32(row * configuration.columns)
            fecPackets.append(
                rowAccumulators[row].buildFECPacket(
                    baseSequenceNumber: rowBase,
                    direction: .row,
                    groupSize: configuration.columns,
                    groupIndex: row
                ))
            fecPacketsGenerated += 1
        }

        // Check if entire matrix is complete → emit column FECs
        if matrixPosition == configuration.matrixSize {
            let base = matrixBaseSequence ?? SequenceNumber(0)
            for colIdx in 0..<configuration.columns
            where columnAccumulators[colIdx].count == configuration.rows {
                let colBase = columnBaseSequence(
                    matrixBase: base, columnIndex: colIdx)
                fecPackets.append(
                    columnAccumulators[colIdx].buildFECPacket(
                        baseSequenceNumber: colBase,
                        direction: .column,
                        groupSize: configuration.rows,
                        groupIndex: colIdx
                    ))
                fecPacketsGenerated += 1
            }
            resetMatrix()
        }

        return fecPackets.isEmpty ? .pending : .fecReady(packets: fecPackets)
    }

    /// Flush any incomplete groups.
    ///
    /// Generates FEC packets for partially-filled groups.
    /// - Returns: FEC packets for incomplete groups.
    public mutating func flush() -> [FECPacket] {
        var fecPackets: [FECPacket] = []
        let base = matrixBaseSequence ?? SequenceNumber(0)

        // Flush incomplete rows
        for row in 0..<configuration.rows {
            if rowAccumulators[row].count > 0
                && rowAccumulators[row].count < configuration.columns
            {
                let rowBase = base + Int32(row * configuration.columns)
                fecPackets.append(
                    rowAccumulators[row].buildFECPacket(
                        baseSequenceNumber: rowBase,
                        direction: .row,
                        groupSize: rowAccumulators[row].count,
                        groupIndex: row
                    ))
                fecPacketsGenerated += 1
            }
        }

        // Flush incomplete columns
        for colIdx in 0..<configuration.columns {
            if columnAccumulators[colIdx].count > 0
                && columnAccumulators[colIdx].count < configuration.rows
            {
                let colBase = columnBaseSequence(
                    matrixBase: base, columnIndex: colIdx)
                fecPackets.append(
                    columnAccumulators[colIdx].buildFECPacket(
                        baseSequenceNumber: colBase,
                        direction: .column,
                        groupSize: columnAccumulators[colIdx].count,
                        groupIndex: colIdx
                    ))
                fecPacketsGenerated += 1
            }
        }

        resetMatrix()
        return fecPackets
    }

    /// Reset encoder state (new matrix).
    public mutating func reset() {
        resetMatrix()
        packetsProcessed = 0
        fecPacketsGenerated = 0
    }

    // MARK: - Private

    /// Compute the column group index for a given matrix position.
    private func columnIndex(row: Int, col: Int) -> Int {
        switch configuration.layout {
        case .even:
            return col
        case .staircase:
            return (col + row) % configuration.columns
        }
    }

    /// Compute the base sequence number for a column group.
    private func columnBaseSequence(
        matrixBase: SequenceNumber,
        columnIndex: Int
    ) -> SequenceNumber {
        // For even layout, column base is the first packet in that column
        // For staircase, the column group spans non-contiguous packets
        // In both cases, use the matrix base + column offset
        matrixBase + Int32(columnIndex)
    }

    /// Reset matrix-level state for a new matrix.
    private mutating func resetMatrix() {
        matrixPosition = 0
        matrixBaseSequence = nil
        for i in 0..<rowAccumulators.count {
            rowAccumulators[i].reset()
        }
        for i in 0..<columnAccumulators.count {
            columnAccumulators[i].reset()
        }
    }
}

// MARK: - Row Accumulator

extension FECEncoder {
    /// Accumulates XOR state for a single row group.
    struct RowAccumulator: Sendable {
        /// Running XOR of payloads.
        var payloadXOR: [UInt8] = []
        /// Running XOR of payload lengths.
        var lengthRecovery: UInt16 = 0
        /// Running XOR of timestamps.
        var timestampRecovery: UInt32 = 0
        /// Number of packets accumulated.
        var count: Int = 0

        /// Accumulate a source packet.
        mutating func accumulate(_ packet: SourcePacket) {
            XORHelper.xorInPlace(&payloadXOR, packet.payload)
            lengthRecovery ^= UInt16(packet.payload.count)
            timestampRecovery ^= packet.timestamp
            count += 1
        }

        /// Build the FEC packet from accumulated state.
        func buildFECPacket(
            baseSequenceNumber: SequenceNumber,
            direction: FECDirection,
            groupSize: Int,
            groupIndex: Int
        ) -> FECPacket {
            FECPacket(
                payloadXOR: payloadXOR,
                lengthRecovery: lengthRecovery,
                timestampRecovery: timestampRecovery,
                baseSequenceNumber: baseSequenceNumber,
                direction: direction,
                groupSize: groupSize,
                groupIndex: groupIndex
            )
        }

        /// Reset accumulator state.
        mutating func reset() {
            payloadXOR = []
            lengthRecovery = 0
            timestampRecovery = 0
            count = 0
        }
    }

    /// Accumulates XOR state for a single column group.
    typealias ColumnAccumulator = RowAccumulator
}
