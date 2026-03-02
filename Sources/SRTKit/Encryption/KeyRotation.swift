// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Manages even/odd SEK rotation for SRT encryption.
///
/// Maintains two key slots (even and odd). Handles the rotation
/// lifecycle: pre-announce, switch, and cleanup.
public struct KeyRotation: Sendable {
    /// Which key slot is active.
    public enum KeyIndex: UInt8, Sendable, Equatable {
        /// Even key (KK = 0b01).
        case even = 1
        /// Odd key (KK = 0b10).
        case odd = 2

        /// The other key index (even↔odd).
        public var other: KeyIndex {
            switch self {
            case .even: return .odd
            case .odd: return .even
            }
        }
    }

    /// Key rotation configuration.
    public struct Configuration: Sendable {
        /// Packets between key refreshes (default: 2^24 ≈ 16.7M).
        public let refreshRate: UInt64
        /// Packets before refresh to send pre-announce (default: 2^12 = 4096).
        public let preAnnounce: UInt64

        /// Creates a key rotation configuration.
        ///
        /// - Parameters:
        ///   - refreshRate: Packets between key refreshes.
        ///   - preAnnounce: Packets before refresh to pre-announce.
        public init(
            refreshRate: UInt64 = 1 << 24,
            preAnnounce: UInt64 = 1 << 12
        ) {
            self.refreshRate = refreshRate
            self.preAnnounce = preAnnounce
        }
    }

    /// Rotation action to take.
    public enum Action: Sendable, Equatable {
        /// No action needed.
        case none
        /// Time to pre-announce the next key.
        case preAnnounce(nextKeyIndex: KeyIndex)
        /// Time to switch to the next key.
        case switchKey(newKeyIndex: KeyIndex)
    }

    /// The rotation configuration.
    public let configuration: Configuration

    /// Current active key index.
    public private(set) var activeKeyIndex: KeyIndex

    /// Key storage for even slot.
    private var evenKey: [UInt8]?

    /// Key storage for odd slot.
    private var oddKey: [UInt8]?

    /// Total packets sent since last rotation.
    public private(set) var packetsSinceRotation: UInt64 = 0

    /// Whether pre-announce has been sent for current rotation cycle.
    public private(set) var preAnnounceSent: Bool = false

    /// Creates a key rotation manager.
    ///
    /// - Parameters:
    ///   - configuration: Rotation configuration.
    ///   - initialKeyIndex: Initial active key index.
    public init(
        configuration: Configuration = .init(),
        initialKeyIndex: KeyIndex = .even
    ) {
        self.configuration = configuration
        self.activeKeyIndex = initialKeyIndex
    }

    /// Record that a packet was sent and check if rotation action needed.
    ///
    /// - Returns: Rotation action to take.
    public mutating func packetSent() -> Action {
        packetsSinceRotation += 1

        let preAnnounceThreshold = configuration.refreshRate - configuration.preAnnounce
        if packetsSinceRotation == preAnnounceThreshold && !preAnnounceSent {
            preAnnounceSent = true
            return .preAnnounce(nextKeyIndex: activeKeyIndex.other)
        }

        if packetsSinceRotation >= configuration.refreshRate {
            return .switchKey(newKeyIndex: activeKeyIndex.other)
        }

        return .none
    }

    /// Set the key for a given index.
    ///
    /// - Parameters:
    ///   - key: Key bytes.
    ///   - index: Key index (even or odd).
    public mutating func setKey(_ key: [UInt8], for index: KeyIndex) {
        switch index {
        case .even: evenKey = key
        case .odd: oddKey = key
        }
    }

    /// Get the key for a given index.
    ///
    /// - Parameter index: Key index.
    /// - Returns: Key bytes, or nil if not set.
    public func key(for index: KeyIndex) -> [UInt8]? {
        switch index {
        case .even: return evenKey
        case .odd: return oddKey
        }
    }

    /// Get the active key.
    public var activeKey: [UInt8]? {
        key(for: activeKeyIndex)
    }

    /// Advance to next key (called after pre-announce + switch).
    public mutating func completeRotation() {
        activeKeyIndex = activeKeyIndex.other
        packetsSinceRotation = 0
        preAnnounceSent = false
    }
}
