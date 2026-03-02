// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Generates unique random SRT Socket IDs.
///
/// Socket IDs are random 32-bit values used to identify SRT connections.
/// The value 0 is reserved and must never be generated.
public enum SocketIDGenerator: Sendable {
    /// Maximum number of attempts to find a non-colliding ID.
    private static let maxAttempts = 1000

    /// Generate a random non-zero 32-bit socket ID.
    ///
    /// - Returns: A random value in the range `1...UInt32.max`.
    public static func generate() -> UInt32 {
        UInt32.random(in: 1...UInt32.max)
    }

    /// Generate a socket ID that doesn't collide with existing IDs.
    ///
    /// Retries up to an internal limit to avoid infinite loops if the
    /// existing set is nearly full.
    /// - Parameter existing: Set of currently active socket IDs.
    /// - Returns: A unique socket ID not in the existing set.
    public static func generate(avoiding existing: Set<UInt32>) -> UInt32 {
        for _ in 0..<maxAttempts {
            let candidate = generate()
            if !existing.contains(candidate) {
                return candidate
            }
        }
        // Fallback: linear scan for an unused ID
        for candidate: UInt32 in 1...UInt32.max where !existing.contains(candidate) {
            return candidate
        }
        return 1
    }
}
