// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A FEC control packet containing XOR parity data.
///
/// Used both for encoding (sender builds from source packets)
/// and decoding (receiver uses to recover lost packets).
public struct FECPacket: Sendable {
    /// XOR of all source packet payloads (padded to max length).
    public let payloadXOR: [UInt8]
    /// XOR of all source packet payload lengths.
    public let lengthRecovery: UInt16
    /// XOR of all source packet timestamp LSBs.
    public let timestampRecovery: UInt32
    /// Base sequence number of the group.
    public let baseSequenceNumber: SequenceNumber
    /// Direction (row or column).
    public let direction: FECDirection
    /// Number of source packets in this group.
    public let groupSize: Int
    /// Column index (for column FEC) or row index (for row FEC).
    public let groupIndex: Int

    /// Creates a FEC packet.
    ///
    /// - Parameters:
    ///   - payloadXOR: XOR of all source packet payloads.
    ///   - lengthRecovery: XOR of all source packet lengths.
    ///   - timestampRecovery: XOR of all source packet timestamps.
    ///   - baseSequenceNumber: Base sequence number of the group.
    ///   - direction: Row or column FEC.
    ///   - groupSize: Number of source packets in the group.
    ///   - groupIndex: Row or column index within the matrix.
    public init(
        payloadXOR: [UInt8],
        lengthRecovery: UInt16,
        timestampRecovery: UInt32,
        baseSequenceNumber: SequenceNumber,
        direction: FECDirection,
        groupSize: Int,
        groupIndex: Int
    ) {
        self.payloadXOR = payloadXOR
        self.lengthRecovery = lengthRecovery
        self.timestampRecovery = timestampRecovery
        self.baseSequenceNumber = baseSequenceNumber
        self.direction = direction
        self.groupSize = groupSize
        self.groupIndex = groupIndex
    }
}
