// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore

/// A NAK (Negative Acknowledgement) packet CIF containing a loss report.
///
/// The loss list uses range-compressed encoding where each entry is either
/// a single lost sequence number or a range of consecutive losses.
public struct NAKPacket: Sendable, Equatable {
    /// A loss list entry representing either a single loss or a range.
    public enum LossEntry: Sendable, Equatable {
        /// A single lost sequence number.
        case single(SequenceNumber)
        /// A range of lost sequence numbers (inclusive on both ends).
        case range(from: SequenceNumber, to: SequenceNumber)
    }

    /// The list of loss entries.
    public let lossEntries: [LossEntry]

    /// Creates a NAK packet with the given loss entries.
    ///
    /// - Parameter lossEntries: The loss entries to include.
    public init(lossEntries: [LossEntry]) {
        self.lossEntries = lossEntries
    }

    /// Expands all loss entries to individual sequence numbers.
    ///
    /// Ranges are expanded to include every sequence number from start to end.
    public var lostSequenceNumbers: [SequenceNumber] {
        var result: [SequenceNumber] = []
        for entry in lossEntries {
            switch entry {
            case .single(let seq):
                result.append(seq)
            case .range(let from, let to):
                let dist = SequenceNumber.distance(from: from, to: to)
                if dist >= 0 {
                    for i in 0...dist {
                        result.append(from + i)
                    }
                }
            }
        }
        return result
    }

    /// Encodes this NAK CIF into a buffer.
    ///
    /// Each single entry is encoded as `0 | 31-bit sequence number`.
    /// Each range is encoded as `1 | 31-bit from_sequence` followed by `0 | 31-bit to_sequence`.
    /// - Parameter buffer: The buffer to write into.
    public func encode(into buffer: inout ByteBuffer) {
        for entry in lossEntries {
            switch entry {
            case .single(let seq):
                buffer.writeInteger(seq.value & 0x7FFF_FFFF)
            case .range(let from, let to):
                buffer.writeInteger(from.value | 0x8000_0000)
                buffer.writeInteger(to.value & 0x7FFF_FFFF)
            }
        }
    }

    /// Decodes a NAK CIF from a buffer.
    ///
    /// - Parameters:
    ///   - buffer: The buffer to read from.
    ///   - cifLength: The length of the CIF in bytes.
    /// - Returns: The decoded NAK packet.
    /// - Throws: `SRTError.invalidPacket` if the buffer contains malformed data.
    public static func decode(from buffer: inout ByteBuffer, cifLength: Int) throws -> NAKPacket {
        var entries: [LossEntry] = []
        let endIndex = buffer.readerIndex + cifLength

        while buffer.readerIndex < endIndex {
            guard let word = buffer.readInteger(as: UInt32.self) else {
                throw SRTError.invalidPacket("Failed to read NAK loss entry")
            }
            let isRange = (word & 0x8000_0000) != 0
            let seq = SequenceNumber(word & 0x7FFF_FFFF)

            if isRange {
                guard let toWord = buffer.readInteger(as: UInt32.self) else {
                    throw SRTError.invalidPacket("Failed to read NAK range end")
                }
                let toSeq = SequenceNumber(toWord & 0x7FFF_FFFF)
                entries.append(.range(from: seq, to: toSeq))
            } else {
                entries.append(.single(seq))
            }
        }

        return NAKPacket(lossEntries: entries)
    }
}
