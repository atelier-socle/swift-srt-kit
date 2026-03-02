// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// MAX_BW configuration mode for LiveCC.
///
/// Controls how the maximum sending bandwidth is determined.
public enum MaxBandwidthMode: Sendable, Equatable {
    /// Direct: user specifies exact bandwidth in bits/second.
    case direct(bitsPerSecond: UInt64)

    /// Relative: based on known input bandwidth + overhead percentage.
    ///
    /// - Parameters:
    ///   - inputBW: Known input bandwidth in bits/second.
    ///   - overheadPercent: Overhead percentage (5–100).
    case relative(inputBW: UInt64, overheadPercent: Int)

    /// Auto: based on estimated input bandwidth + overhead percentage.
    ///
    /// Uses bandwidth estimation from received ACKs.
    /// - Parameter overheadPercent: Overhead percentage (5–100).
    case auto(overheadPercent: Int)

    /// Default overhead percentage.
    public static let defaultOverheadPercent: Int = 25

    /// Calculate the effective MAX_BW in bits/second.
    ///
    /// - Parameter estimatedBW: Estimated bandwidth for auto mode (bits/second).
    /// - Returns: Effective maximum bandwidth in bits/second.
    public func effectiveBandwidth(estimatedBW: UInt64) -> UInt64 {
        switch self {
        case .direct(let bitsPerSecond):
            return bitsPerSecond
        case .relative(let inputBW, let overheadPercent):
            return inputBW + inputBW * UInt64(overheadPercent) / 100
        case .auto(let overheadPercent):
            return estimatedBW + estimatedBW * UInt64(overheadPercent) / 100
        }
    }
}
