// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Outcome of a completed SRT handshake.
///
/// Contains the negotiated connection parameters established during the handshake,
/// including peer identity, SRT version, capability flags, and latencies.
public struct HandshakeResult: Sendable, Equatable {
    /// The peer's SRT socket identifier.
    public let peerSocketID: UInt32
    /// The negotiated SRT version.
    public let negotiatedSRTVersion: UInt32
    /// The negotiated SRT capability flags.
    public let negotiatedFlags: SRTFlags
    /// The negotiated sender TSBPD delay in milliseconds.
    public let senderTSBPDDelay: UInt16
    /// The negotiated receiver TSBPD delay in milliseconds.
    public let receiverTSBPDDelay: UInt16
    /// The peer's initial packet sequence number (for receiving).
    public let initialSequenceNumber: SequenceNumber
    /// The local initial packet sequence number (for sending).
    public let localInitialSequenceNumber: SequenceNumber
    /// The negotiated maximum transmission unit size.
    public let maxTransmissionUnitSize: UInt32
    /// The negotiated maximum flow window size.
    public let maxFlowWindowSize: UInt32
    /// The stream ID if provided during the handshake, otherwise nil.
    public let streamID: String?
    /// The peer's IP address.
    public let peerAddress: SRTPeerAddress
    /// The encryption salt from key derivation, or nil if no encryption.
    public let encryptionSalt: [UInt8]?
    /// The Stream Encrypting Key (SEK), or nil if no encryption.
    public let encryptionSEK: [UInt8]?

    /// Creates a new handshake result.
    ///
    /// - Parameters:
    ///   - peerSocketID: The peer's SRT socket identifier.
    ///   - negotiatedSRTVersion: The negotiated SRT version.
    ///   - negotiatedFlags: The negotiated SRT capability flags.
    ///   - senderTSBPDDelay: The negotiated sender TSBPD delay in milliseconds.
    ///   - receiverTSBPDDelay: The negotiated receiver TSBPD delay in milliseconds.
    ///   - initialSequenceNumber: The peer's initial packet sequence number.
    ///   - localInitialSequenceNumber: The local initial packet sequence number.
    ///   - maxTransmissionUnitSize: The negotiated MTU size.
    ///   - maxFlowWindowSize: The negotiated flow window size.
    ///   - streamID: The stream ID, or nil.
    ///   - peerAddress: The peer's IP address.
    ///   - encryptionSalt: The encryption salt, or nil.
    ///   - encryptionSEK: The Stream Encrypting Key, or nil.
    public init(
        peerSocketID: UInt32,
        negotiatedSRTVersion: UInt32,
        negotiatedFlags: SRTFlags,
        senderTSBPDDelay: UInt16,
        receiverTSBPDDelay: UInt16,
        initialSequenceNumber: SequenceNumber,
        localInitialSequenceNumber: SequenceNumber = SequenceNumber(0),
        maxTransmissionUnitSize: UInt32,
        maxFlowWindowSize: UInt32,
        streamID: String?,
        peerAddress: SRTPeerAddress,
        encryptionSalt: [UInt8]? = nil,
        encryptionSEK: [UInt8]? = nil
    ) {
        self.peerSocketID = peerSocketID
        self.negotiatedSRTVersion = negotiatedSRTVersion
        self.negotiatedFlags = negotiatedFlags
        self.senderTSBPDDelay = senderTSBPDDelay
        self.receiverTSBPDDelay = receiverTSBPDDelay
        self.initialSequenceNumber = initialSequenceNumber
        self.localInitialSequenceNumber = localInitialSequenceNumber
        self.maxTransmissionUnitSize = maxTransmissionUnitSize
        self.maxFlowWindowSize = maxFlowWindowSize
        self.streamID = streamID
        self.peerAddress = peerAddress
        self.encryptionSalt = encryptionSalt
        self.encryptionSEK = encryptionSEK
    }
}
