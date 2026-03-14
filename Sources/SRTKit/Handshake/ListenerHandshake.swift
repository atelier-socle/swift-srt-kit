// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Listener-side SRT handshake state machine.
///
/// Unlike ``CallerHandshake``, the listener does not maintain persistent state per connection
/// during Phase 1. The induction phase is completely stateless — cookie validation replaces
/// stored state. Phase 2 (conclusion) creates and processes the connection.
///
/// This is a pure logic state machine that produces ``HandshakeAction`` values
/// without performing any I/O.
public struct ListenerHandshake: Sendable {
    /// The current handshake state.
    public private(set) var state: HandshakeState
    /// The handshake configuration.
    public let configuration: HandshakeConfiguration

    /// Handler for access control (StreamID validation).
    ///
    /// Returns nil to accept the connection, or a ``SRTRejectionReason`` to reject it.
    public typealias AccessControlHandler = @Sendable (String) -> SRTRejectionReason?

    /// The unwrapped Stream Encrypting Key from the caller's KMREQ.
    private var unwrappedSEK: [UInt8] = []
    /// The salt from the caller's KMREQ.
    private var receivedSalt: [UInt8] = []
    /// The received KMREQ to echo back as KMRSP.
    private var receivedKMREQ: KeyMaterialPacket?

    /// Creates a new listener handshake state machine.
    ///
    /// - Parameter configuration: The handshake configuration.
    public init(configuration: HandshakeConfiguration) {
        self.state = .idle
        self.configuration = configuration
    }

    /// Processes an induction request (Phase 1 — stateless).
    ///
    /// Generates a SYN cookie and returns the induction response.
    /// This method does NOT change the listener's state because Phase 1 is stateless.
    /// - Parameters:
    ///   - handshake: The received induction CIF.
    ///   - peerAddress: The sender's address (used for cookie generation).
    ///   - cookieSecret: Server-local secret for cookie generation.
    ///   - peerPort: The peer's port number for cookie generation.
    ///   - timeBucket: The current time bucket for cookie expiry.
    /// - Returns: The action containing the induction response to send.
    public func processInduction(
        handshake: HandshakePacket,
        from peerAddress: SRTPeerAddress,
        cookieSecret: [UInt8],
        peerPort: UInt16 = 0,
        timeBucket: UInt32 = 0
    ) -> HandshakeAction {
        // Generate cookie from peer identity
        let cookie = CookieGenerator.generate(
            peerAddress: peerAddress,
            peerPort: peerPort,
            secret: cookieSecret,
            timeBucket: timeBucket
        )

        // SRT magic number in Induction Response signals HSv5 support to the caller.
        let extensionField: UInt16 = 0x4A17

        let responsePacket = HandshakePacket(
            version: 5,
            encryptionField: configuration.cipherType,
            extensionField: extensionField,
            initialPacketSequenceNumber: SequenceNumber(0),
            maxTransmissionUnitSize: configuration.maxTransmissionUnitSize,
            maxFlowWindowSize: configuration.maxFlowWindowSize,
            handshakeType: .induction,
            srtSocketID: configuration.localSocketID,
            synCookie: cookie,
            peerIPAddress: peerAddress
        )

        return .sendPacket(responsePacket, extensions: [])
    }

    /// Processes a conclusion request (Phase 2 — establishes connection).
    ///
    /// Validates the SYN cookie, processes extensions, negotiates latency,
    /// and produces the conclusion response or rejection.
    /// - Parameters:
    ///   - handshake: The received conclusion CIF.
    ///   - extensions: Extensions received (HSREQ, KMREQ, SID).
    ///   - peerAddress: The sender's address.
    ///   - cookieSecret: Same secret used in ``processInduction(handshake:from:cookieSecret:peerPort:timeBucket:)``.
    ///   - peerPort: The peer's port number.
    ///   - timeBucket: The current time bucket.
    ///   - accessControl: Optional handler to validate the StreamID.
    /// - Returns: An array of actions containing the response and/or completion.
    public mutating func processConclusion(
        handshake: HandshakePacket,
        extensions: [HandshakeExtensionData],
        from peerAddress: SRTPeerAddress,
        cookieSecret: [UInt8],
        peerPort: UInt16 = 0,
        timeBucket: UInt32 = 0,
        accessControl: AccessControlHandler? = nil
    ) -> [HandshakeAction] {
        if let error = validateConclusionRequest(
            handshake: handshake, peerAddress: peerAddress,
            cookieSecret: cookieSecret, peerPort: peerPort, timeBucket: timeBucket
        ) {
            return error
        }

        let parsed = parseExtensions(
            extensions, handshake: handshake,
            peerAddress: peerAddress, accessControl: accessControl
        )
        if let error = parsed.error { return error }

        return buildConclusionResponse(
            handshake: handshake, peerAddress: peerAddress,
            remoteHSREQ: parsed.hsreq, streamID: parsed.streamID
        )
    }

    // MARK: - Conclusion helpers

    /// Validates state, handshake type, version, and SYN cookie.
    private mutating func validateConclusionRequest(
        handshake: HandshakePacket,
        peerAddress: SRTPeerAddress,
        cookieSecret: [UInt8],
        peerPort: UInt16,
        timeBucket: UInt32
    ) -> [HandshakeAction]? {
        guard state == .idle || state == .inductionReceived else {
            return [.error(.handshakeFailed("Cannot process conclusion in state \(state)"))]
        }
        guard handshake.handshakeType == .conclusion else {
            state = .failed
            return [.error(.handshakeFailed("Expected conclusion, got \(handshake.handshakeType)"))]
        }
        guard handshake.version == 5 else {
            state = .failed
            return [.error(.versionMismatch)]
        }
        let cookieValid = CookieGenerator.validate(
            cookie: handshake.synCookie, peerAddress: peerAddress,
            peerPort: peerPort, secret: cookieSecret, currentTimeBucket: timeBucket
        )
        guard cookieValid else {
            state = .failed
            return buildRejection(reason: .rdvCookie, handshake: handshake, peerAddress: peerAddress)
        }
        return nil
    }

    /// Parsed extension data from conclusion request.
    private struct ParsedExtensions {
        var hsreq: SRTHandshakeExtension?
        var streamID: String?
        var kmreq: KeyMaterialPacket?
        var error: [HandshakeAction]?
    }

    /// Extracts extensions, validates encryption compatibility, and runs access control.
    private mutating func parseExtensions(
        _ extensions: [HandshakeExtensionData],
        handshake: HandshakePacket,
        peerAddress: SRTPeerAddress,
        accessControl: AccessControlHandler?
    ) -> ParsedExtensions {
        var parsed = ParsedExtensions()
        for ext in extensions {
            switch ext {
            case .hsreq(let hsreq):
                parsed.hsreq = hsreq
            case .streamID(let sid):
                parsed.streamID = sid
            case .kmreq where configuration.cipherType == 0:
                state = .failed
                parsed.error = buildRejection(
                    reason: .unsecure, handshake: handshake, peerAddress: peerAddress
                )
                return parsed
            case .kmreq(let km):
                parsed.kmreq = km
            default:
                break
            }
        }

        if let error = checkEncryptionMismatch(extensions, handshake: handshake, peerAddress: peerAddress) {
            parsed.error = error
            return parsed
        }

        // Unwrap SEK from KMREQ if encryption is configured
        if let km = parsed.kmreq, let passphrase = configuration.passphrase {
            if let error = unwrapKeyMaterial(
                km: km, passphrase: passphrase,
                handshake: handshake, peerAddress: peerAddress
            ) {
                parsed.error = error
                return parsed
            }
        }

        if let sid = parsed.streamID, let handler = accessControl,
            let rejectionReason = handler(sid)
        {
            state = .failed
            parsed.error = buildRejection(
                reason: rejectionReason, handshake: handshake, peerAddress: peerAddress
            )
        }
        return parsed
    }

    /// Unwraps the SEK from a KMREQ using the passphrase.
    ///
    /// On success stores the unwrapped SEK, salt, and KMREQ in `self`.
    /// - Returns: Error actions on failure, or nil on success.
    private mutating func unwrapKeyMaterial(
        km: KeyMaterialPacket,
        passphrase: String,
        handshake: HandshakePacket,
        peerAddress: SRTPeerAddress
    ) -> [HandshakeAction]? {
        guard let keySize = KeySize(rawValue: Int(km.keyLength)) else {
            state = .failed
            return buildRejection(
                reason: .rdvCookie, handshake: handshake, peerAddress: peerAddress)
        }
        do {
            let kek = try KeyDerivation.deriveKEK(
                passphrase: passphrase, salt: km.salt, keySize: keySize)
            let sek = try KeyWrap.unwrap(wrappedKey: km.wrappedKeys, withKEK: kek)
            unwrappedSEK = sek
            receivedSalt = km.salt
            receivedKMREQ = km
            return nil
        } catch {
            state = .failed
            return buildRejection(
                reason: .rdvCookie, handshake: handshake, peerAddress: peerAddress)
        }
    }

    /// Checks whether the listener expects encryption but the caller provides none.
    private mutating func checkEncryptionMismatch(
        _ extensions: [HandshakeExtensionData],
        handshake: HandshakePacket,
        peerAddress: SRTPeerAddress
    ) -> [HandshakeAction]? {
        guard configuration.cipherType != 0 && handshake.encryptionField == 0 else { return nil }
        let hasKMREQ = extensions.contains { if case .kmreq = $0 { true } else { false } }
        guard !hasKMREQ else { return nil }
        state = .failed
        return buildRejection(reason: .unsecure, handshake: handshake, peerAddress: peerAddress)
    }

    /// Negotiated parameters from HSREQ extension.
    private struct NegotiatedParams {
        let version: UInt32
        let flags: SRTFlags
        let senderDelay: UInt16
        let receiverDelay: UInt16
    }

    /// Negotiates version, flags, and latency from the remote HSREQ extension.
    private func negotiateParams(
        remoteHSREQ: SRTHandshakeExtension?
    ) -> NegotiatedParams {
        guard let hsreq = remoteHSREQ else {
            return NegotiatedParams(
                version: configuration.srtVersion, flags: configuration.srtFlags,
                senderDelay: configuration.senderTSBPDDelay,
                receiverDelay: configuration.receiverTSBPDDelay)
        }
        let latency = LatencyNegotiator.negotiate(
            localSenderDelay: configuration.senderTSBPDDelay,
            localReceiverDelay: configuration.receiverTSBPDDelay,
            remoteSenderDelay: hsreq.senderTSBPDDelay,
            remoteReceiverDelay: hsreq.receiverTSBPDDelay)
        return NegotiatedParams(
            version: min(configuration.srtVersion, hsreq.srtVersion),
            flags: SRTFlags(rawValue: configuration.srtFlags.rawValue & hsreq.srtFlags.rawValue),
            senderDelay: latency.senderDelay,
            receiverDelay: latency.receiverDelay)
    }

    /// Negotiates latency, builds HSRSP/KMRSP extensions, and returns success actions.
    private mutating func buildConclusionResponse(
        handshake: HandshakePacket,
        peerAddress: SRTPeerAddress,
        remoteHSREQ: SRTHandshakeExtension?,
        streamID: String?
    ) -> [HandshakeAction] {
        let params = negotiateParams(remoteHSREQ: remoteHSREQ)

        let hsrsp = SRTHandshakeExtension(
            srtVersion: params.version, srtFlags: params.flags,
            receiverTSBPDDelay: params.receiverDelay, senderTSBPDDelay: params.senderDelay)
        var responseExtensions: [HandshakeExtensionData] = [.hsrsp(hsrsp)]
        var respExtFlags: HandshakePacket.ExtensionFlags = [.hsreq]
        if let km = buildKMRSP(peerEncryptionField: handshake.encryptionField) {
            responseExtensions.append(.kmrsp(km))
            respExtFlags.insert(.kmreq)
        }

        let listenerISN = SequenceNumber(UInt32.random(in: 0...SequenceNumber.max))
        let responsePacket = HandshakePacket(
            version: 5,
            encryptionField: configuration.cipherType,
            extensionField: respExtFlags.rawValue,
            initialPacketSequenceNumber: listenerISN,
            maxTransmissionUnitSize: configuration.maxTransmissionUnitSize,
            maxFlowWindowSize: configuration.maxFlowWindowSize,
            handshakeType: .conclusion,
            srtSocketID: configuration.localSocketID,
            synCookie: 0,
            peerIPAddress: peerAddress)

        state = .done
        let result = HandshakeResult(
            peerSocketID: handshake.srtSocketID,
            negotiatedSRTVersion: params.version, negotiatedFlags: params.flags,
            senderTSBPDDelay: params.senderDelay, receiverTSBPDDelay: params.receiverDelay,
            initialSequenceNumber: handshake.initialPacketSequenceNumber,
            localInitialSequenceNumber: listenerISN,
            maxTransmissionUnitSize: min(
                configuration.maxTransmissionUnitSize, handshake.maxTransmissionUnitSize),
            maxFlowWindowSize: min(configuration.maxFlowWindowSize, handshake.maxFlowWindowSize),
            streamID: streamID, peerAddress: peerAddress,
            encryptionSalt: unwrappedSEK.isEmpty ? nil : receivedSalt,
            encryptionSEK: unwrappedSEK.isEmpty ? nil : unwrappedSEK)

        return [
            .sendPacket(responsePacket, extensions: responseExtensions),
            .completed(result)
        ]
    }

    /// Handles a timeout event.
    ///
    /// - Returns: The error action.
    public mutating func timeout() -> HandshakeAction {
        switch state {
        case .inductionReceived, .conclusionReceived:
            state = .failed
            return .error(.handshakeTimeout)
        case .idle:
            return .error(.handshakeFailed("Timeout before handshake started"))
        default:
            return .error(.handshakeFailed("Timeout in state \(state)"))
        }
    }

    // MARK: - Private

    /// Builds a rejection response with the given reason.
    private func buildRejection(
        reason: SRTRejectionReason,
        handshake: HandshakePacket,
        peerAddress: SRTPeerAddress
    ) -> [HandshakeAction] {
        let rejPacket = HandshakePacket(
            version: 5,
            handshakeType: .init(rawValue: reason.rawValue),
            srtSocketID: configuration.localSocketID,
            peerIPAddress: peerAddress
        )
        return [
            .sendPacket(rejPacket, extensions: []),
            .error(.connectionRejected(reason))
        ]
    }

    /// Builds a KMRSP key material packet by echoing the received KMREQ.
    private func buildKMRSP(peerEncryptionField: UInt16) -> KeyMaterialPacket? {
        guard configuration.cipherType != 0 && peerEncryptionField != 0 else { return nil }
        // Echo the received KMREQ as KMRSP per SRT spec
        if let km = receivedKMREQ {
            return km
        }
        return nil
    }

}
