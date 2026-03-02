// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Configuration for SRT handshake negotiation.
///
/// Contains the local socket's identity and desired connection parameters
/// that will be negotiated during the handshake.
public struct HandshakeConfiguration: Sendable {
    /// The local SRT socket identifier.
    public let localSocketID: UInt32
    /// The local SRT version (e.g., `0x010501` for v1.5.1).
    public let srtVersion: UInt32
    /// The local SRT capability flags.
    public let srtFlags: SRTFlags
    /// The desired sender TSBPD delay in milliseconds.
    public let senderTSBPDDelay: UInt16
    /// The desired receiver TSBPD delay in milliseconds.
    public let receiverTSBPDDelay: UInt16
    /// The maximum transmission unit size in bytes.
    public let maxTransmissionUnitSize: UInt32
    /// The maximum flow window size in packets.
    public let maxFlowWindowSize: UInt32
    /// The optional stream ID for access control.
    public let streamID: String?
    /// The optional encryption passphrase.
    public let passphrase: String?
    /// The cipher type (0=none, 2=AES-128, 3=AES-192, 4=AES-256).
    public let cipherType: UInt16
    /// The handshake timeout in milliseconds.
    public let handshakeTimeoutMs: UInt64

    /// Creates a new handshake configuration.
    ///
    /// - Parameters:
    ///   - localSocketID: The local SRT socket identifier.
    ///   - srtVersion: The SRT version to advertise.
    ///   - srtFlags: The SRT capability flags to advertise.
    ///   - senderTSBPDDelay: The desired sender TSBPD delay in milliseconds.
    ///   - receiverTSBPDDelay: The desired receiver TSBPD delay in milliseconds.
    ///   - maxTransmissionUnitSize: The maximum transmission unit size.
    ///   - maxFlowWindowSize: The maximum flow window size.
    ///   - streamID: Optional stream ID for access control.
    ///   - passphrase: Optional encryption passphrase.
    ///   - cipherType: The cipher type for encryption.
    ///   - handshakeTimeoutMs: The handshake timeout in milliseconds.
    public init(
        localSocketID: UInt32,
        srtVersion: UInt32 = 0x0001_0501,
        srtFlags: SRTFlags = [.tsbpdSender, .tsbpdReceiver, .tlpktDrop, .periodicNAK, .rexmitFlag],
        senderTSBPDDelay: UInt16 = 120,
        receiverTSBPDDelay: UInt16 = 120,
        maxTransmissionUnitSize: UInt32 = 1500,
        maxFlowWindowSize: UInt32 = 8192,
        streamID: String? = nil,
        passphrase: String? = nil,
        cipherType: UInt16 = 0,
        handshakeTimeoutMs: UInt64 = 3000
    ) {
        self.localSocketID = localSocketID
        self.srtVersion = srtVersion
        self.srtFlags = srtFlags
        self.senderTSBPDDelay = senderTSBPDDelay
        self.receiverTSBPDDelay = receiverTSBPDDelay
        self.maxTransmissionUnitSize = maxTransmissionUnitSize
        self.maxFlowWindowSize = maxFlowWindowSize
        self.streamID = streamID
        self.passphrase = passphrase
        self.cipherType = cipherType
        self.handshakeTimeoutMs = handshakeTimeoutMs
    }
}
