// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A 31-bit wrapping sequence number used in SRT packet headers.
///
/// SRT sequence numbers occupy 31 bits, ranging from `0` to `0x7FFFFFFF` (2^31 - 1).
/// Arithmetic wraps around this range, and comparison uses signed distance
/// to correctly handle wrap-around scenarios.
public struct SequenceNumber: Sendable, Hashable, CustomStringConvertible {
    /// The maximum valid sequence number value (2^31 - 1).
    public static let max: UInt32 = 0x7FFF_FFFF

    /// The raw 31-bit sequence number value.
    public let value: UInt32

    /// Creates a sequence number from a raw value.
    ///
    /// The value is masked to 31 bits.
    /// - Parameter value: The raw sequence number value.
    public init(_ value: UInt32) {
        self.value = value & Self.max
    }

    /// Computes the signed distance from one sequence number to another.
    ///
    /// The distance accounts for wrap-around in the 31-bit space.
    /// A positive result means `b` is ahead of `a`; negative means behind.
    /// - Parameters:
    ///   - a: The starting sequence number.
    ///   - b: The ending sequence number.
    /// - Returns: The signed distance from `a` to `b`.
    public static func distance(from a: SequenceNumber, to b: SequenceNumber) -> Int32 {
        let range = Int64(Self.max) + 1
        let halfRange = range / 2
        let diff = ((Int64(b.value) - Int64(a.value)) % range + range) % range
        if diff <= halfRange {
            return Int32(diff)
        }
        return Int32(diff - range)
    }

    /// Advances a sequence number by a signed offset.
    ///
    /// - Parameters:
    ///   - lhs: The base sequence number.
    ///   - rhs: The signed offset to add.
    /// - Returns: A new sequence number advanced by the offset, wrapping within 31-bit range.
    public static func + (lhs: SequenceNumber, rhs: Int32) -> SequenceNumber {
        let result = Int64(lhs.value) + Int64(rhs)
        let range = Int64(Self.max) + 1
        let wrapped = ((result % range) + range) % range
        return SequenceNumber(UInt32(wrapped))
    }

    /// Retreats a sequence number by a signed offset.
    ///
    /// - Parameters:
    ///   - lhs: The base sequence number.
    ///   - rhs: The signed offset to subtract.
    /// - Returns: A new sequence number retreated by the offset, wrapping within 31-bit range.
    public static func - (lhs: SequenceNumber, rhs: Int32) -> SequenceNumber {
        lhs + (-rhs)
    }

    /// A textual representation of the sequence number.
    public var description: String {
        "\(value)"
    }
}

extension SequenceNumber: Comparable {
    /// Compares two sequence numbers using signed distance for wrap-around correctness.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand sequence number.
    ///   - rhs: The right-hand sequence number.
    /// - Returns: `true` if `lhs` is logically before `rhs` in the wrapping sequence space.
    public static func < (lhs: SequenceNumber, rhs: SequenceNumber) -> Bool {
        distance(from: lhs, to: rhs) > 0
    }
}
