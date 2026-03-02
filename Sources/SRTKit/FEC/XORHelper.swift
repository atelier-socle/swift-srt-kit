// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Utility functions for XOR operations on byte arrays.
///
/// Handles payloads of different lengths by zero-padding
/// the shorter array.
public enum XORHelper: Sendable {
    /// XOR two byte arrays, zero-padding the shorter one.
    ///
    /// - Parameters:
    ///   - a: First byte array.
    ///   - b: Second byte array.
    /// - Returns: XOR result with length = max(a.count, b.count).
    public static func xor(_ a: [UInt8], _ b: [UInt8]) -> [UInt8] {
        let maxLen = Swift.max(a.count, b.count)
        guard maxLen > 0 else { return [] }
        var result = [UInt8](repeating: 0, count: maxLen)
        for i in 0..<a.count {
            result[i] = a[i]
        }
        for i in 0..<b.count {
            result[i] ^= b[i]
        }
        return result
    }

    /// XOR a value into an accumulator in place.
    ///
    /// Extends the accumulator if the value is longer.
    /// - Parameters:
    ///   - accumulator: The accumulator to modify.
    ///   - value: The value to XOR in.
    public static func xorInPlace(_ accumulator: inout [UInt8], _ value: [UInt8]) {
        if value.count > accumulator.count {
            accumulator.append(
                contentsOf: [UInt8](repeating: 0, count: value.count - accumulator.count))
        }
        for i in 0..<value.count {
            accumulator[i] ^= value[i]
        }
    }

    /// XOR multiple byte arrays together.
    ///
    /// - Parameter arrays: The arrays to XOR.
    /// - Returns: Combined XOR result.
    public static func xorAll(_ arrays: [[UInt8]]) -> [UInt8] {
        guard !arrays.isEmpty else { return [] }
        var result = arrays[0]
        for i in 1..<arrays.count {
            result = xor(result, arrays[i])
        }
        return result
    }
}
