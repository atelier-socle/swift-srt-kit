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
    /// The initial packet sequence number for data transfer.
    public let initialSequenceNumber: SequenceNumber
    /// The negotiated maximum transmission unit size.
    public let maxTransmissionUnitSize: UInt32
    /// The negotiated maximum flow window size.
    public let maxFlowWindowSize: UInt32
    /// The stream ID if provided during the handshake, otherwise nil.
    public let streamID: String?
    /// The peer's IP address.
    public let peerAddress: SRTPeerAddress

    /// Creates a new handshake result.
    ///
    /// - Parameters:
    ///   - peerSocketID: The peer's SRT socket identifier.
    ///   - negotiatedSRTVersion: The negotiated SRT version.
    ///   - negotiatedFlags: The negotiated SRT capability flags.
    ///   - senderTSBPDDelay: The negotiated sender TSBPD delay in milliseconds.
    ///   - receiverTSBPDDelay: The negotiated receiver TSBPD delay in milliseconds.
    ///   - initialSequenceNumber: The initial packet sequence number.
    ///   - maxTransmissionUnitSize: The negotiated MTU size.
    ///   - maxFlowWindowSize: The negotiated flow window size.
    ///   - streamID: The stream ID, or nil.
    ///   - peerAddress: The peer's IP address.
    public init(
        peerSocketID: UInt32,
        negotiatedSRTVersion: UInt32,
        negotiatedFlags: SRTFlags,
        senderTSBPDDelay: UInt16,
        receiverTSBPDDelay: UInt16,
        initialSequenceNumber: SequenceNumber,
        maxTransmissionUnitSize: UInt32,
        maxFlowWindowSize: UInt32,
        streamID: String?,
        peerAddress: SRTPeerAddress
    ) {
        self.peerSocketID = peerSocketID
        self.negotiatedSRTVersion = negotiatedSRTVersion
        self.negotiatedFlags = negotiatedFlags
        self.senderTSBPDDelay = senderTSBPDDelay
        self.receiverTSBPDDelay = receiverTSBPDDelay
        self.initialSequenceNumber = initialSequenceNumber
        self.maxTransmissionUnitSize = maxTransmissionUnitSize
        self.maxFlowWindowSize = maxFlowWindowSize
        self.streamID = streamID
        self.peerAddress = peerAddress
    }
}
