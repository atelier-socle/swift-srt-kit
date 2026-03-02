// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// An SRT control packet used for protocol signaling.
///
/// Control packets have `F=1` (bit 0 of word 0). The header format is:
/// - **Word 0:** `1` (1 bit) | control type (15 bits) | subtype (16 bits)
/// - **Word 1:** type-specific information (32 bits)
/// - **Word 2:** timestamp (32 bits)
/// - **Word 3:** destination socket ID (32 bits)
/// - **Remaining:** control information field (CIF)
public struct SRTControlPacket: Sendable, Hashable {
    /// The control packet type.
    public let controlType: ControlType

    /// The control packet subtype.
    public let subtype: UInt16

    /// Type-specific information field.
    public let typeSpecificInfo: UInt32

    /// The packet timestamp in microseconds.
    public let timestamp: UInt32

    /// The destination socket identifier.
    public let destinationSocketID: UInt32

    /// The control information field (CIF) payload.
    public let controlInfoField: [UInt8]

    /// Creates a new SRT control packet.
    ///
    /// - Parameters:
    ///   - controlType: The control packet type.
    ///   - subtype: The control packet subtype.
    ///   - typeSpecificInfo: Type-specific information field.
    ///   - timestamp: The packet timestamp in microseconds.
    ///   - destinationSocketID: The destination socket identifier.
    ///   - controlInfoField: The control information field payload.
    public init(
        controlType: ControlType,
        subtype: UInt16 = 0,
        typeSpecificInfo: UInt32 = 0,
        timestamp: UInt32 = 0,
        destinationSocketID: UInt32 = 0,
        controlInfoField: [UInt8] = []
    ) {
        self.controlType = controlType
        self.subtype = subtype
        self.typeSpecificInfo = typeSpecificInfo
        self.timestamp = timestamp
        self.destinationSocketID = destinationSocketID
        self.controlInfoField = controlInfoField
    }
}
