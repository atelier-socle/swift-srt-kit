// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Generates and validates SYN cookies for the listener handshake.
///
/// Cookies are deterministic: generated from peer address, port, secret, and time bucket.
/// This allows the listener to verify cookies without storing state from Phase 1.
/// Uses FNV-1a hashing for efficient, Foundation-free cookie generation.
public enum CookieGenerator: Sendable {
    /// FNV-1a 32-bit offset basis.
    private static let fnvOffsetBasis: UInt32 = 0x811C_9DC5
    /// FNV-1a 32-bit prime.
    private static let fnvPrime: UInt32 = 0x0100_0193

    /// Generates a SYN cookie for the given peer.
    ///
    /// - Parameters:
    ///   - peerAddress: The peer's IP address.
    ///   - peerPort: The peer's port number.
    ///   - secret: Server-local random secret bytes.
    ///   - timeBucket: Time bucket for expiry (e.g., seconds / 60).
    /// - Returns: A 32-bit cookie value.
    public static func generate(
        peerAddress: SRTPeerAddress,
        peerPort: UInt16,
        secret: [UInt8],
        timeBucket: UInt32
    ) -> UInt32 {
        var hash = fnvOffsetBasis

        // Hash the peer address bytes
        switch peerAddress {
        case .ipv4(let addr):
            hash = feedUInt32(hash, addr)
        case .ipv6(let high, let low):
            hash = feedUInt64(hash, high)
            hash = feedUInt64(hash, low)
        }

        // Hash the port
        hash = feedByte(hash, UInt8(peerPort >> 8))
        hash = feedByte(hash, UInt8(peerPort & 0xFF))

        // Hash the secret
        for byte in secret {
            hash = feedByte(hash, byte)
        }

        // Hash the time bucket
        hash = feedUInt32(hash, timeBucket)

        return hash
    }

    /// Validates a cookie by regenerating it and comparing.
    ///
    /// Checks the current time bucket and the previous one for tolerance,
    /// allowing for cookies generated just before a bucket boundary.
    /// - Parameters:
    ///   - cookie: The cookie to validate.
    ///   - peerAddress: The peer's IP address.
    ///   - peerPort: The peer's port number.
    ///   - secret: The same server-local secret used for generation.
    ///   - currentTimeBucket: The current time bucket value.
    /// - Returns: `true` if the cookie is valid.
    public static func validate(
        cookie: UInt32,
        peerAddress: SRTPeerAddress,
        peerPort: UInt16,
        secret: [UInt8],
        currentTimeBucket: UInt32
    ) -> Bool {
        // Check current time bucket
        let currentCookie = generate(
            peerAddress: peerAddress,
            peerPort: peerPort,
            secret: secret,
            timeBucket: currentTimeBucket
        )
        if cookie == currentCookie { return true }

        // Check previous time bucket for grace period
        guard currentTimeBucket > 0 else { return false }
        let previousCookie = generate(
            peerAddress: peerAddress,
            peerPort: peerPort,
            secret: secret,
            timeBucket: currentTimeBucket - 1
        )
        return cookie == previousCookie
    }

    // MARK: - FNV-1a helpers

    /// Feeds a single byte into the FNV-1a hash.
    private static func feedByte(_ hash: UInt32, _ byte: UInt8) -> UInt32 {
        (hash ^ UInt32(byte)) &* fnvPrime
    }

    /// Feeds a 32-bit value into the FNV-1a hash (big-endian byte order).
    private static func feedUInt32(_ hash: UInt32, _ value: UInt32) -> UInt32 {
        var h = hash
        h = feedByte(h, UInt8((value >> 24) & 0xFF))
        h = feedByte(h, UInt8((value >> 16) & 0xFF))
        h = feedByte(h, UInt8((value >> 8) & 0xFF))
        h = feedByte(h, UInt8(value & 0xFF))
        return h
    }

    /// Feeds a 64-bit value into the FNV-1a hash (big-endian byte order).
    private static func feedUInt64(_ hash: UInt32, _ value: UInt64) -> UInt32 {
        var h = hash
        h = feedUInt32(h, UInt32((value >> 32) & 0xFFFF_FFFF))
        h = feedUInt32(h, UInt32(value & 0xFFFF_FFFF))
        return h
    }
}
