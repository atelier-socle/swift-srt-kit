// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Caller-side SRT handshake state machine.
///
/// This is a pure logic state machine that produces ``HandshakeAction`` values
/// without performing any I/O. The caller of this type is responsible for
/// sending packets and scheduling timeouts.
///
/// Usage:
/// 1. Call ``start()`` to get the induction packet to send.
/// 2. Feed received packets via ``receive(handshake:extensions:from:)`` to get the next action.
/// 3. The state machine drives through: idle -> inductionSent -> conclusionSent -> done/failed.
public struct CallerHandshake: Sendable {
    /// The current handshake state.
    public private(set) var state: HandshakeState
    /// The handshake configuration.
    public let configuration: HandshakeConfiguration

    /// The SYN cookie received from the listener during induction.
    private var receivedCookie: UInt32 = 0
    /// The peer's socket ID received during induction.
    private var peerSocketID: UInt32 = 0
    /// The peer's encryption field value from induction.
    private var peerEncryptionField: UInt16 = 0

    /// Creates a new caller handshake state machine.
    ///
    /// - Parameter configuration: The handshake configuration.
    public init(configuration: HandshakeConfiguration) {
        self.state = .idle
        self.configuration = configuration
    }

    /// Starts the handshake by generating the induction packet.
    ///
    /// Transitions from `.idle` to `.inductionSent`.
    /// - Returns: An array of actions: the induction packet to send and a wait action.
    public mutating func start() -> [HandshakeAction] {
        guard state == .idle else {
            return [.error(.handshakeFailed("Cannot start: already in state \(state)"))]
        }

        let inductionPacket = HandshakePacket(
            version: 4,
            encryptionField: 0,
            extensionField: 2,
            initialPacketSequenceNumber: SequenceNumber(0),
            maxTransmissionUnitSize: configuration.maxTransmissionUnitSize,
            maxFlowWindowSize: configuration.maxFlowWindowSize,
            handshakeType: .induction,
            srtSocketID: configuration.localSocketID,
            synCookie: 0,
            peerIPAddress: .ipv4(0)
        )

        state = .inductionSent
        return [
            .sendPacket(inductionPacket, extensions: []),
            .waitForResponse(timeoutMs: configuration.handshakeTimeoutMs)
        ]
    }

    /// Processes a received handshake packet and returns the next actions.
    ///
    /// - Parameters:
    ///   - handshake: The received handshake CIF.
    ///   - extensions: Any extensions received with the handshake.
    ///   - peerAddress: The sender's address.
    /// - Returns: An array of actions to take next.
    public mutating func receive(
        handshake: HandshakePacket,
        extensions: [HandshakeExtensionData],
        from peerAddress: SRTPeerAddress
    ) -> [HandshakeAction] {
        switch state {
        case .inductionSent:
            return handleInductionResponse(handshake: handshake, peerAddress: peerAddress)
        case .conclusionSent:
            return handleConclusionResponse(
                handshake: handshake, extensions: extensions, peerAddress: peerAddress
            )
        case .idle:
            return [.error(.handshakeFailed("Cannot receive: handshake not started"))]
        case .done:
            return [.error(.handshakeFailed("Cannot receive: handshake already done"))]
        case .failed:
            return [.error(.handshakeFailed("Cannot receive: handshake failed"))]
        default:
            return [.error(.handshakeFailed("Unexpected state for receive: \(state)"))]
        }
    }

    /// Handles a timeout event.
    ///
    /// Transitions to `.failed` if the handshake was in progress.
    /// - Returns: The error action.
    public mutating func timeout() -> HandshakeAction {
        switch state {
        case .inductionSent, .conclusionSent:
            state = .failed
            return .error(.handshakeTimeout)
        case .idle:
            return .error(.handshakeFailed("Timeout before handshake started"))
        default:
            return .error(.handshakeFailed("Timeout in state \(state)"))
        }
    }

    // MARK: - Private

    /// Handles the induction response from the listener.
    private mutating func handleInductionResponse(
        handshake: HandshakePacket,
        peerAddress: SRTPeerAddress
    ) -> [HandshakeAction] {
        guard handshake.handshakeType == .induction else {
            state = .failed
            return [.error(.handshakeFailed("Expected induction response, got \(handshake.handshakeType)"))]
        }
        guard handshake.version == 5 else {
            state = .failed
            return [.error(.versionMismatch)]
        }

        receivedCookie = handshake.synCookie
        peerSocketID = handshake.srtSocketID
        peerEncryptionField = handshake.encryptionField

        // Build extensions for the conclusion
        var extensionsToSend: [HandshakeExtensionData] = []

        // HSREQ is always included
        let hsreq = SRTHandshakeExtension(
            srtVersion: configuration.srtVersion,
            srtFlags: configuration.srtFlags,
            receiverTSBPDDelay: configuration.receiverTSBPDDelay,
            senderTSBPDDelay: configuration.senderTSBPDDelay
        )
        extensionsToSend.append(.hsreq(hsreq))

        // KMREQ if encryption is configured
        if configuration.passphrase != nil && configuration.cipherType != 0 {
            let km = KeyMaterialPacket(
                cipher: cipherTypeFromField(configuration.cipherType),
                salt: Array(repeating: 0, count: 16),
                keyLength: keyLengthFromCipherType(configuration.cipherType),
                wrappedKeys: Array(repeating: 0, count: Int(keyLengthFromCipherType(configuration.cipherType)) + 8)
            )
            extensionsToSend.append(.kmreq(km))
        }

        // StreamID if configured
        if let sid = configuration.streamID {
            extensionsToSend.append(.streamID(sid))
        }

        // Build extension flags
        var extFlags: HandshakePacket.ExtensionFlags = [.hsreq]
        if configuration.passphrase != nil && configuration.cipherType != 0 {
            extFlags.insert(.kmreq)
        }
        if configuration.streamID != nil {
            extFlags.insert(.config)
        }

        let conclusionPacket = HandshakePacket(
            version: 5,
            encryptionField: configuration.cipherType,
            extensionField: extFlags.rawValue,
            initialPacketSequenceNumber: SequenceNumber(0),
            maxTransmissionUnitSize: configuration.maxTransmissionUnitSize,
            maxFlowWindowSize: configuration.maxFlowWindowSize,
            handshakeType: .conclusion,
            srtSocketID: configuration.localSocketID,
            synCookie: receivedCookie,
            peerIPAddress: peerAddress
        )

        state = .conclusionSent
        return [
            .sendPacket(conclusionPacket, extensions: extensionsToSend),
            .waitForResponse(timeoutMs: configuration.handshakeTimeoutMs)
        ]
    }

    /// Handles the conclusion response from the listener.
    private mutating func handleConclusionResponse(
        handshake: HandshakePacket,
        extensions: [HandshakeExtensionData],
        peerAddress: SRTPeerAddress
    ) -> [HandshakeAction] {
        // Check for rejection (handshake type is not conclusion/done)
        if handshake.handshakeType != .conclusion && handshake.handshakeType != .done {
            state = .failed
            let rejCode = handshake.handshakeType.rawValue
            if let reason = SRTRejectionReason(rawValue: rejCode) {
                return [.error(.connectionRejected(reason))]
            }
            return [.error(.connectionRejected(.unknown))]
        }

        // Extract HSRSP to negotiate latency
        var negotiatedSenderDelay = configuration.senderTSBPDDelay
        var negotiatedReceiverDelay = configuration.receiverTSBPDDelay
        var negotiatedVersion = configuration.srtVersion
        var negotiatedFlags = configuration.srtFlags
        var streamID: String?

        for ext in extensions {
            switch ext {
            case .hsrsp(let hsrsp):
                let latency = LatencyNegotiator.negotiate(
                    localSenderDelay: configuration.senderTSBPDDelay,
                    localReceiverDelay: configuration.receiverTSBPDDelay,
                    remoteSenderDelay: hsrsp.senderTSBPDDelay,
                    remoteReceiverDelay: hsrsp.receiverTSBPDDelay
                )
                negotiatedSenderDelay = latency.senderDelay
                negotiatedReceiverDelay = latency.receiverDelay
                negotiatedVersion = min(configuration.srtVersion, hsrsp.srtVersion)
                negotiatedFlags = SRTFlags(rawValue: configuration.srtFlags.rawValue & hsrsp.srtFlags.rawValue)
            case .streamID(let sid):
                streamID = sid
            default:
                break
            }
        }

        state = .done
        let result = HandshakeResult(
            peerSocketID: handshake.srtSocketID,
            negotiatedSRTVersion: negotiatedVersion,
            negotiatedFlags: negotiatedFlags,
            senderTSBPDDelay: negotiatedSenderDelay,
            receiverTSBPDDelay: negotiatedReceiverDelay,
            initialSequenceNumber: handshake.initialPacketSequenceNumber,
            maxTransmissionUnitSize: min(
                configuration.maxTransmissionUnitSize, handshake.maxTransmissionUnitSize
            ),
            maxFlowWindowSize: min(configuration.maxFlowWindowSize, handshake.maxFlowWindowSize),
            streamID: streamID ?? configuration.streamID,
            peerAddress: peerAddress
        )
        return [.completed(result)]
    }

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
