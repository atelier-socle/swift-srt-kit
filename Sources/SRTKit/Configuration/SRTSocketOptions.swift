// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Complete set of SRT socket options.
///
/// Maps to SRTO_* constants from the SRT protocol specification.
/// All values have sensible defaults for live streaming.
public struct SRTSocketOptions: Sendable, Equatable {
    // MARK: - Timing

    /// TSBPD latency in microseconds (default: 120_000 = 120ms).
    public var latency: UInt64

    /// Minimum latency the peer should use in microseconds (default: 0).
    public var peerLatency: UInt64

    /// Enable too-late packet drop (default: true).
    public var tlpktdrop: Bool

    /// Enable timestamp-based packet delivery (default: true).
    public var tsbpd: Bool

    // MARK: - Buffers

    /// Send buffer size in packets (default: 8192).
    public var sendBufferSize: Int

    /// Receive buffer size in packets (default: 8192).
    public var receiveBufferSize: Int

    /// Flow control window in packets (default: 25600).
    public var flowWindowSize: Int

    // MARK: - Network

    /// Maximum payload size per packet in bytes (default: 1316).
    /// Range: 72-1500.
    public var maxPayloadSize: Int

    /// IP Time-To-Live (default: 64).
    public var ipTTL: Int

    /// IP Type of Service / DSCP (default: 0).
    public var ipTOS: Int

    // MARK: - Congestion

    /// Congestion control algorithm name (default: "live").
    public var congestionControl: String

    /// Maximum bandwidth in bits/second (default: 0 = auto).
    public var maxBandwidth: UInt64

    /// Known input bandwidth in bits/second (default: 0 = not set).
    public var inputBandwidth: UInt64

    /// Overhead percentage for bandwidth calculation (default: 25).
    /// Range: 5-100.
    public var overheadPercent: Int

    // MARK: - Encryption

    /// Encryption passphrase (nil = no encryption, 10-79 chars).
    public var passphrase: String?

    /// AES key size (default: .aes128).
    public var keySize: KeySize

    /// Cipher mode (default: .ctr).
    public var cipherMode: CipherMode

    /// Key rotation interval in packets (default: 2^24).
    public var kmRefreshRate: UInt64

    /// Pre-announce before rotation in packets (default: 2^12).
    public var kmPreAnnounce: UInt64

    /// Reject unencrypted peers when passphrase is set (default: true).
    public var enforcedEncryption: Bool

    // MARK: - FEC

    /// FEC configuration (nil = no FEC).
    public var fecConfiguration: FECConfiguration?

    // MARK: - Timeouts

    /// Connection timeout in microseconds (default: 3_000_000).
    public var connectTimeout: UInt64

    /// Keepalive interval in microseconds (default: 1_000_000).
    public var keepaliveInterval: UInt64

    /// Keepalive timeout in microseconds (default: 5_000_000).
    public var keepaliveTimeout: UInt64

    // MARK: - Mode

    /// Transmission type (default: .live).
    public var transmissionType: TransmissionType

    /// Transmission type enum.
    public enum TransmissionType: String, Sendable, CaseIterable {
        /// Live streaming mode (TSBPD, pacing, TLPKTDROP).
        case live
        /// File transfer mode (no TSBPD, windowing, no TLPKTDROP).
        case file
    }

    /// Default options for live streaming.
    public static let `default` = SRTSocketOptions()

    /// Creates socket options with default values.
    public init() {
        self.latency = 120_000
        self.peerLatency = 0
        self.tlpktdrop = true
        self.tsbpd = true
        self.sendBufferSize = 8192
        self.receiveBufferSize = 8192
        self.flowWindowSize = 25_600
        self.maxPayloadSize = 1316
        self.ipTTL = 64
        self.ipTOS = 0
        self.congestionControl = "live"
        self.maxBandwidth = 0
        self.inputBandwidth = 0
        self.overheadPercent = 25
        self.passphrase = nil
        self.keySize = .aes128
        self.cipherMode = .ctr
        self.kmRefreshRate = 1 << 24
        self.kmPreAnnounce = 1 << 12
        self.enforcedEncryption = true
        self.fecConfiguration = nil
        self.connectTimeout = 3_000_000
        self.keepaliveInterval = 1_000_000
        self.keepaliveTimeout = 5_000_000
        self.transmissionType = .live
    }
}
