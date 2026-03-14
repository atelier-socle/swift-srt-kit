// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Rendezvous SRT handshake state machine.
///
/// Implements the three-phase rendezvous handshake where both peers
/// act as caller and listener simultaneously. This enables NAT traversal
/// and peer-to-peer connections.
///
/// Usage:
/// 1. Call ``start()`` to get the WAVEAHAND packet to send.
/// 2. Feed received packets via ``receive(handshake:extensions:from:)`` to get next action(s).
/// 3. State machine drives through: idle -> waveahandSent -> conclusionSent -> agreementSent -> done
public struct RendezvousHandshake: Sendable {
    /// The current handshake state.
    public private(set) var state: RendezvousState
    /// The determined role after receiving peer's WAVEAHAND.
    public private(set) var role: RendezvousRole?
    /// The handshake configuration.
    public let configuration: HandshakeConfiguration

    /// The peer's socket ID learned from Phase 1.
    private var peerSocketID: UInt32 = 0
    /// The peer's address learned from Phase 1.
    private var peerAddress: SRTPeerAddress = .ipv4(0)
    /// The local initial sequence number advertised in the Conclusion.
    private var localISN: SequenceNumber = SequenceNumber(0)

    /// Creates a new rendezvous handshake state machine.
    ///
    /// - Parameter configuration: The handshake configuration.
    public init(configuration: HandshakeConfiguration) {
        self.state = .idle
        self.configuration = configuration
    }

    /// Start the rendezvous handshake by generating the WAVEAHAND packet.
    ///
    /// Transitions from `.idle` to `.waveahandSent`.
    /// - Returns: An array of actions: the WAVEAHAND packet and a wait action.
    public mutating func start() -> [HandshakeAction] {
        guard state == .idle else {
            return [.error(.handshakeFailed("Cannot start: already in state \(state)"))]
        }

        let waveahandPacket = HandshakePacket(
            version: 5,
            extensionField: 2,
            maxTransmissionUnitSize: configuration.maxTransmissionUnitSize,
            maxFlowWindowSize: configuration.maxFlowWindowSize,
            handshakeType: .waveahand,
            srtSocketID: configuration.localSocketID,
            synCookie: 0
        )

        state = .waveahandSent
        return [
            .sendPacket(waveahandPacket, extensions: []),
            .waitForResponse(timeoutMs: configuration.handshakeTimeoutMs)
        ]
    }

    /// Process a received handshake packet and return the next action(s).
    ///
    /// - Parameters:
    ///   - handshake: The received handshake CIF.
    ///   - extensions: Any extensions received with the handshake.
    ///   - peerAddr: The sender's address.
    /// - Returns: An array of actions to take next.
    public mutating func receive(
        handshake: HandshakePacket,
        extensions: [HandshakeExtensionData],
        from peerAddr: SRTPeerAddress
    ) -> [HandshakeAction] {
        switch state {
        case .waveahandSent:
            return handleWaveahandResponse(handshake: handshake, peerAddr: peerAddr)
        case .conclusionSent:
            return handleConclusionResponse(
                handshake: handshake, extensions: extensions, peerAddr: peerAddr
            )
        case .agreementSent:
            return handleAgreementResponse(handshake: handshake, peerAddr: peerAddr)
        case .idle:
            return [.error(.handshakeFailed("Cannot receive: handshake not started"))]
        case .done:
            return [.error(.handshakeFailed("Cannot receive: handshake already done"))]
        case .failed:
            return [.error(.handshakeFailed("Cannot receive: handshake failed"))]
        }
    }

    /// Handle a timeout event.
    ///
    /// Transitions to `.failed` if the handshake was in progress.
    /// - Returns: The error action.
    public mutating func timeout() -> HandshakeAction {
        switch state {
        case .waveahandSent, .conclusionSent, .agreementSent:
            state = .failed
            return .error(.handshakeTimeout)
        case .idle:
            return .error(.handshakeFailed("Timeout before handshake started"))
        default:
            return .error(.handshakeFailed("Timeout in state \(state)"))
        }
    }

    // MARK: - Phase handlers

    /// Handles receiving a WAVEAHAND from the peer (Phase 1 -> Phase 2).
    private mutating func handleWaveahandResponse(
        handshake: HandshakePacket,
        peerAddr: SRTPeerAddress
    ) -> [HandshakeAction] {
        guard handshake.handshakeType == .waveahand else {
            state = .failed
            return [
                .error(
                    .handshakeFailed(
                        "Expected waveahand, got \(handshake.handshakeType)"
                    ))
            ]
        }

        peerSocketID = handshake.srtSocketID
        peerAddress = peerAddr

        guard
            let determinedRole = RendezvousRole.determine(
                localSocketID: configuration.localSocketID,
                remoteSocketID: peerSocketID
            )
        else {
            state = .failed
            return [.error(.handshakeFailed("Socket ID collision"))]
        }

        role = determinedRole
        return buildConclusion(peerAddr: peerAddr)
    }

    /// Builds the CONCLUSION packet with extensions based on role.
    private mutating func buildConclusion(
        peerAddr: SRTPeerAddress
    ) -> [HandshakeAction] {
        var extensionsToSend: [HandshakeExtensionData] = []

        let hsreq = SRTHandshakeExtension(
            srtVersion: configuration.srtVersion,
            srtFlags: configuration.srtFlags,
            receiverTSBPDDelay: configuration.receiverTSBPDDelay,
            senderTSBPDDelay: configuration.senderTSBPDDelay
        )
        extensionsToSend.append(.hsreq(hsreq))

        if configuration.passphrase != nil && configuration.cipherType != 0 {
            let km = KeyMaterialPacket(
                cipher: cipherTypeFromField(configuration.cipherType),
                salt: Array(repeating: 0, count: 16),
                keyLength: keyLengthFromCipherType(configuration.cipherType),
                wrappedKeys: Array(
                    repeating: 0,
                    count: Int(keyLengthFromCipherType(configuration.cipherType)) + 8
                )
            )
            extensionsToSend.append(.kmreq(km))
        }

        if let sid = configuration.streamID {
            extensionsToSend.append(.streamID(sid))
        }

        var extFlags: HandshakePacket.ExtensionFlags = [.hsreq]
        if configuration.passphrase != nil && configuration.cipherType != 0 {
            extFlags.insert(.kmreq)
        }
        if configuration.streamID != nil {
            extFlags.insert(.config)
        }

        localISN = SequenceNumber(UInt32.random(in: 0...SequenceNumber.max))

        let conclusionPacket = HandshakePacket(
            version: 5,
            encryptionField: configuration.cipherType,
            extensionField: extFlags.rawValue,
            initialPacketSequenceNumber: localISN,
            maxTransmissionUnitSize: configuration.maxTransmissionUnitSize,
            maxFlowWindowSize: configuration.maxFlowWindowSize,
            handshakeType: .conclusion,
            srtSocketID: configuration.localSocketID,
            synCookie: 0,
            peerIPAddress: peerAddr
        )

        state = .conclusionSent
        return [
            .sendPacket(conclusionPacket, extensions: extensionsToSend),
            .waitForResponse(timeoutMs: configuration.handshakeTimeoutMs)
        ]
    }

    /// Handles receiving a CONCLUSION from the peer (Phase 2 -> Phase 3).
    private mutating func handleConclusionResponse(
        handshake: HandshakePacket,
        extensions: [HandshakeExtensionData],
        peerAddr: SRTPeerAddress
    ) -> [HandshakeAction] {
        // Fast path: peer already sent AGREEMENT (skipped ahead)
        if handshake.handshakeType == .agreement {
            return completeHandshake(handshake: handshake, peerAddr: peerAddr)
        }

        // Check for rejection
        if handshake.handshakeType != .conclusion {
            state = .failed
            let rejCode = handshake.handshakeType.rawValue
            if let reason = SRTRejectionReason(rawValue: rejCode) {
                return [.error(.connectionRejected(reason))]
            }
            return [.error(.connectionRejected(.unknown))]
        }

        // Process extensions and negotiate
        let negotiated = negotiateFromExtensions(extensions)

        let agreementPacket = HandshakePacket(
            version: 5,
            handshakeType: .agreement,
            srtSocketID: configuration.localSocketID,
            peerIPAddress: peerAddr
        )

        state = .agreementSent
        return [
            .sendPacket(agreementPacket, extensions: []),
            .waitForResponse(timeoutMs: configuration.handshakeTimeoutMs),
            .completed(
                HandshakeResult(
                    peerSocketID: handshake.srtSocketID,
                    negotiatedSRTVersion: negotiated.version,
                    negotiatedFlags: negotiated.flags,
                    senderTSBPDDelay: negotiated.senderDelay,
                    receiverTSBPDDelay: negotiated.receiverDelay,
                    initialSequenceNumber: handshake.initialPacketSequenceNumber,
                    localInitialSequenceNumber: localISN,
                    maxTransmissionUnitSize: min(
                        configuration.maxTransmissionUnitSize,
                        handshake.maxTransmissionUnitSize
                    ),
                    maxFlowWindowSize: min(
                        configuration.maxFlowWindowSize,
                        handshake.maxFlowWindowSize
                    ),
                    streamID: negotiated.streamID ?? configuration.streamID,
                    peerAddress: peerAddr
                ))
        ]
    }

    /// Handles receiving an AGREEMENT from the peer (Phase 3 -> done).
    private mutating func handleAgreementResponse(
        handshake: HandshakePacket,
        peerAddr: SRTPeerAddress
    ) -> [HandshakeAction] {
        guard handshake.handshakeType == .agreement else {
            state = .failed
            return [
                .error(
                    .handshakeFailed(
                        "Expected agreement, got \(handshake.handshakeType)"
                    ))
            ]
        }

        state = .done
        return []
    }

    /// Completes the handshake immediately (fast path from AGREEMENT).
    private mutating func completeHandshake(
        handshake: HandshakePacket,
        peerAddr: SRTPeerAddress
    ) -> [HandshakeAction] {
        state = .done
        return [
            .completed(
                HandshakeResult(
                    peerSocketID: handshake.srtSocketID,
                    negotiatedSRTVersion: configuration.srtVersion,
                    negotiatedFlags: configuration.srtFlags,
                    senderTSBPDDelay: configuration.senderTSBPDDelay,
                    receiverTSBPDDelay: configuration.receiverTSBPDDelay,
                    initialSequenceNumber: handshake.initialPacketSequenceNumber,
                    localInitialSequenceNumber: localISN,
                    maxTransmissionUnitSize: configuration.maxTransmissionUnitSize,
                    maxFlowWindowSize: configuration.maxFlowWindowSize,
                    streamID: configuration.streamID,
                    peerAddress: peerAddr
                ))
        ]
    }

    // MARK: - Negotiation

    /// Negotiated extension values.
    private struct NegotiatedValues {
        var senderDelay: UInt16
        var receiverDelay: UInt16
        var version: UInt32
        var flags: SRTFlags
        var streamID: String?
    }

    /// Extracts and negotiates values from peer extensions.
    private func negotiateFromExtensions(
        _ extensions: [HandshakeExtensionData]
    ) -> NegotiatedValues {
        var result = NegotiatedValues(
            senderDelay: configuration.senderTSBPDDelay,
            receiverDelay: configuration.receiverTSBPDDelay,
            version: configuration.srtVersion,
            flags: configuration.srtFlags
        )

        for ext in extensions {
            switch ext {
            case .hsreq(let hs), .hsrsp(let hs):
                let latency = LatencyNegotiator.negotiate(
                    localSenderDelay: configuration.senderTSBPDDelay,
                    localReceiverDelay: configuration.receiverTSBPDDelay,
                    remoteSenderDelay: hs.senderTSBPDDelay,
                    remoteReceiverDelay: hs.receiverTSBPDDelay
                )
                result.senderDelay = latency.senderDelay
                result.receiverDelay = latency.receiverDelay
                result.version = min(configuration.srtVersion, hs.srtVersion)
                result.flags = SRTFlags(
                    rawValue: configuration.srtFlags.rawValue & hs.srtFlags.rawValue
                )
            case .streamID(let sid):
                result.streamID = sid
            default:
                break
            }
        }

        return result
    }

    // MARK: - Cipher helpers

    /// Converts a cipher type field value to a ``KeyMaterialPacket/CipherType``.
    private func cipherTypeFromField(_ field: UInt16) -> KeyMaterialPacket.CipherType {
        switch field {
        case 2: .aesCTR
        case 3: .aesGCM
        default: .none
        }
    }

    /// Returns the key length in bytes for the given cipher type field.
    private func keyLengthFromCipherType(_ cipherType: UInt16) -> UInt16 {
        switch cipherType {
        case 2: 16
        case 3: 16
        case 4: 32
        default: 16
        }
    }
}
