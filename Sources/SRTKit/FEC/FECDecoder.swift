// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Recovers lost packets using FEC parity data.
///
/// The decoder collects received source packets and FEC packets,
/// then attempts to recover any missing packets using XOR.
/// Supports iterative 2D recovery (row → column → row → ...).
public struct FECDecoder: Sendable {
    /// A recovered packet.
    public struct RecoveredPacket: Sendable {
        /// The recovered packet's sequence number.
        public let sequenceNumber: SequenceNumber
        /// The recovered payload.
        public let payload: [UInt8]
        /// The recovered timestamp.
        public let timestamp: UInt32

        /// Creates a recovered packet.
        ///
        /// - Parameters:
        ///   - sequenceNumber: The recovered sequence number.
        ///   - payload: The recovered payload.
        ///   - timestamp: The recovered timestamp.
        public init(
            sequenceNumber: SequenceNumber,
            payload: [UInt8],
            timestamp: UInt32
        ) {
            self.sequenceNumber = sequenceNumber
            self.payload = payload
            self.timestamp = timestamp
        }
    }

    /// Result of attempting recovery.
    public enum RecoveryResult: Sendable {
        /// No recovery needed (no losses in completed groups).
        case noLoss
        /// Successfully recovered one or more packets.
        case recovered(packets: [RecoveredPacket])
        /// Losses detected but cannot recover (too many in same group).
        case irrecoverable(missingCount: Int)
        /// Not enough data yet (groups still incomplete).
        case incomplete
    }

    /// Stored source packet data for XOR recovery.
    private struct StoredPacket: Sendable {
        let payload: [UInt8]
        let timestamp: UInt32
    }

    /// The FEC configuration.
    public let configuration: FECConfiguration

    /// Received source packets indexed by sequence number.
    private var receivedPackets: [SequenceNumber: StoredPacket] = [:]

    /// Received row FEC packets indexed by row index.
    private var rowFECPackets: [Int: FECPacket] = [:]

    /// Received column FEC packets indexed by column index.
    private var columnFECPackets: [Int: FECPacket] = [:]

    /// Base sequence number of the current matrix.
    private var matrixBase: SequenceNumber?

    /// Total number of source packets expected for the current matrix.
    private var expectedCount: Int { configuration.matrixSize }

    /// Number of packets successfully recovered.
    public private(set) var totalRecovered: Int = 0

    /// Number of irrecoverable losses.
    public private(set) var totalIrrecoverable: Int = 0

    /// Creates a FEC decoder.
    ///
    /// - Parameter configuration: The FEC configuration.
    public init(configuration: FECConfiguration) {
        self.configuration = configuration
    }

    /// Record a received source packet.
    ///
    /// - Parameters:
    ///   - sequenceNumber: The packet's sequence number.
    ///   - payload: The packet payload.
    ///   - timestamp: The packet timestamp.
    public mutating func receiveSourcePacket(
        sequenceNumber: SequenceNumber,
        payload: [UInt8],
        timestamp: UInt32
    ) {
        if let current = matrixBase {
            // Keep the lowest sequence number as base
            if SequenceNumber.distance(from: sequenceNumber, to: current) > 0 {
                matrixBase = sequenceNumber
            }
        } else {
            matrixBase = sequenceNumber
        }
        receivedPackets[sequenceNumber] = StoredPacket(
            payload: payload, timestamp: timestamp)
    }

    /// Record a received FEC packet.
    ///
    /// - Parameter fecPacket: The FEC packet to record.
    public mutating func receiveFECPacket(_ fecPacket: FECPacket) {
        // Derive the actual matrix base from FEC packet info
        let derivedBase: SequenceNumber
        switch fecPacket.direction {
        case .row:
            derivedBase =
                fecPacket.baseSequenceNumber
                - Int32(fecPacket.groupIndex * configuration.columns)
            rowFECPackets[fecPacket.groupIndex] = fecPacket
        case .column:
            derivedBase =
                fecPacket.baseSequenceNumber
                - Int32(fecPacket.groupIndex)
            columnFECPackets[fecPacket.groupIndex] = fecPacket
        }

        if let current = matrixBase {
            if SequenceNumber.distance(from: derivedBase, to: current) > 0 {
                matrixBase = derivedBase
            }
        } else {
            matrixBase = derivedBase
        }
    }

    /// Attempt to recover lost packets using available FEC data.
    ///
    /// For 2D FEC, performs iterative recovery:
    /// 1. Try each row group (recover if exactly 1 missing)
    /// 2. Try each column group (recover if exactly 1 missing)
    /// 3. Repeat until no more progress
    /// - Returns: Recovery result.
    public mutating func attemptRecovery() -> RecoveryResult {
        guard let base = matrixBase else { return .incomplete }

        let allSeqs = matrixSequenceNumbers(base: base)
        if allSeqs.allSatisfy({ receivedPackets[$0] != nil }) {
            return .noLoss
        }
        if rowFECPackets.isEmpty && columnFECPackets.isEmpty {
            return .incomplete
        }

        let recovered = iterativeRecovery(base: base)

        if !recovered.isEmpty {
            let stillMissing = allSeqs.filter { receivedPackets[$0] == nil }
            totalIrrecoverable += stillMissing.count
            return .recovered(packets: recovered)
        }

        let remaining = allSeqs.filter { receivedPackets[$0] == nil }.count
        totalIrrecoverable += remaining
        return .irrecoverable(missingCount: remaining)
    }

    /// Perform iterative row → column recovery passes.
    private mutating func iterativeRecovery(
        base: SequenceNumber
    ) -> [RecoveredPacket] {
        var allRecovered: [RecoveredPacket] = []
        var madeProgress = true
        while madeProgress {
            madeProgress = false
            madeProgress = recoverRows(base: base, into: &allRecovered) || madeProgress
            madeProgress = recoverColumns(base: base, into: &allRecovered) || madeProgress
        }
        return allRecovered
    }

    /// Try to recover one missing packet from each row group.
    private mutating func recoverRows(
        base: SequenceNumber,
        into recovered: inout [RecoveredPacket]
    ) -> Bool {
        var progress = false
        for row in 0..<configuration.rows {
            guard let fec = rowFECPackets[row] else { continue }
            let seqs = rowSequenceNumbers(base: base, row: row)
            let missing = seqs.filter { receivedPackets[$0] == nil }
            guard missing.count == 1 else { continue }
            let pkt = recoverPacket(missingSeq: missing[0], groupSeqs: seqs, fecPacket: fec)
            receivedPackets[missing[0]] = StoredPacket(payload: pkt.payload, timestamp: pkt.timestamp)
            recovered.append(pkt)
            totalRecovered += 1
            progress = true
        }
        return progress
    }

    /// Try to recover one missing packet from each column group.
    private mutating func recoverColumns(
        base: SequenceNumber,
        into recovered: inout [RecoveredPacket]
    ) -> Bool {
        var progress = false
        for col in 0..<configuration.columns {
            guard let fec = columnFECPackets[col] else { continue }
            let seqs = columnSequenceNumbers(base: base, column: col)
            let missing = seqs.filter { receivedPackets[$0] == nil }
            guard missing.count == 1 else { continue }
            let pkt = recoverPacket(missingSeq: missing[0], groupSeqs: seqs, fecPacket: fec)
            receivedPackets[missing[0]] = StoredPacket(payload: pkt.payload, timestamp: pkt.timestamp)
            recovered.append(pkt)
            totalRecovered += 1
            progress = true
        }
        return progress
    }

    /// Advance the decoder past a completed matrix.
    ///
    /// Call when all packets in the current matrix have been
    /// processed (delivered or dropped).
    /// - Parameter baseSequenceNumber: Start of next matrix.
    public mutating func advanceMatrix(to baseSequenceNumber: SequenceNumber) {
        receivedPackets.removeAll()
        rowFECPackets.removeAll()
        columnFECPackets.removeAll()
        matrixBase = baseSequenceNumber
    }

    /// Reset decoder state.
    public mutating func reset() {
        receivedPackets.removeAll()
        rowFECPackets.removeAll()
        columnFECPackets.removeAll()
        matrixBase = nil
        totalRecovered = 0
        totalIrrecoverable = 0
    }

    // MARK: - Private

    /// Get all sequence numbers for the current matrix.
    private func matrixSequenceNumbers(base: SequenceNumber) -> [SequenceNumber] {
        (0..<configuration.matrixSize).map { base + Int32($0) }
    }

    /// Get sequence numbers for a row.
    private func rowSequenceNumbers(
        base: SequenceNumber, row: Int
    ) -> [SequenceNumber] {
        let rowStart = row * configuration.columns
        return (0..<configuration.columns).map { base + Int32(rowStart + $0) }
    }

    /// Get sequence numbers for a column.
    private func columnSequenceNumbers(
        base: SequenceNumber, column: Int
    ) -> [SequenceNumber] {
        (0..<configuration.rows).map { row in
            let linearIndex = row * configuration.columns
            switch configuration.layout {
            case .even:
                return base + Int32(linearIndex + column)
            case .staircase:
                // For staircase: column group index = (col + row) % columns
                // Reverse: find col such that (col + row) % columns == column
                let col =
                    (column - row % configuration.columns + configuration.columns)
                    % configuration.columns
                return base + Int32(linearIndex + col)
            }
        }
    }

    /// Recover a single missing packet from a group.
    private func recoverPacket(
        missingSeq: SequenceNumber,
        groupSeqs: [SequenceNumber],
        fecPacket: FECPacket
    ) -> RecoveredPacket {
        // Start with FEC XOR data
        var recoveredPayload = fecPacket.payloadXOR
        var recoveredLength = fecPacket.lengthRecovery
        var recoveredTimestamp = fecPacket.timestampRecovery

        // XOR out all received packets in the group
        for seq in groupSeqs where seq != missingSeq {
            if let packet = receivedPackets[seq] {
                recoveredPayload = XORHelper.xor(recoveredPayload, packet.payload)
                recoveredLength ^= UInt16(packet.payload.count)
                recoveredTimestamp ^= packet.timestamp
            }
        }

        // Trim payload to recovered length
        let finalLength = Int(recoveredLength)
        let trimmedPayload: [UInt8]
        if finalLength > 0, finalLength <= recoveredPayload.count {
            trimmedPayload = Array(recoveredPayload.prefix(finalLength))
        } else {
            trimmedPayload = recoveredPayload
        }

        return RecoveredPacket(
            sequenceNumber: missingSeq,
            payload: trimmedPayload,
            timestamp: recoveredTimestamp
        )
    }
}
