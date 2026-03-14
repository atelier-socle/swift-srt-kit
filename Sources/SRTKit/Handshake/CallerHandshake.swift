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
    /// The generated encryption salt (stored for HandshakeResult).
    private var generatedSalt: [UInt8] = []
    /// The generated Stream Encrypting Key (stored for HandshakeResult).
    private var generatedSEK: [UInt8] = []
    /// The local initial sequence number advertised in the Conclusion.
    private var localISN: SequenceNumber = SequenceNumber(0)

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
        if let passphrase = configuration.passphrase, configuration.cipherType != 0 {
            guard let km = generateKeyMaterial(passphrase: passphrase) else {
                return [.error(.handshakeFailed("Key material generation failed"))]
            }
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
            let rawCode = handshake.handshakeType.rawValue
            // SRT sends rejection codes as 1000 + reason offset on the wire
            let normalizedCode = rawCode >= 1000 ? rawCode - 1000 : rawCode
            if let reason = SRTRejectionReason(rawValue: normalizedCode) {
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
            localInitialSequenceNumber: localISN,
            maxTransmissionUnitSize: min(
                configuration.maxTransmissionUnitSize, handshake.maxTransmissionUnitSize
            ),
            maxFlowWindowSize: min(configuration.maxFlowWindowSize, handshake.maxFlowWindowSize),
            streamID: streamID ?? configuration.streamID,
            peerAddress: peerAddress,
            encryptionSalt: generatedSalt.isEmpty ? nil : generatedSalt,
            encryptionSEK: generatedSEK.isEmpty ? nil : generatedSEK
        )
        return [.completed(result)]
    }

    /// Generates KMREQ key material (salt, SEK, wrapped keys).
    ///
    /// On success stores the generated salt and SEK in `self` for ``HandshakeResult``.
    /// - Parameter passphrase: The encryption passphrase.
    /// - Returns: The ``KeyMaterialPacket``, or nil on failure (state set to `.failed`).
    private mutating func generateKeyMaterial(
        passphrase: String
    ) -> KeyMaterialPacket? {
        let keyLen = keyLengthFromCipherType(configuration.cipherType)
        guard let keySize = keySizeFromLength(keyLen) else {
            state = .failed
            return nil
        }

        let salt = KeyDerivation.generateSalt()
        var sek = [UInt8](repeating: 0, count: Int(keyLen))
        for i in 0..<sek.count {
            sek[i] = UInt8.random(in: 0...255)
        }

        do {
            let kek = try KeyDerivation.deriveKEK(
                passphrase: passphrase, salt: salt, keySize: keySize)
            let wrappedKeys = try KeyWrap.wrap(key: sek, withKEK: kek)

            generatedSalt = salt
            generatedSEK = sek

            return KeyMaterialPacket(
                cipher: cipherTypeFromField(configuration.cipherType),
                salt: salt,
                keyLength: keyLen,
                wrappedKeys: wrappedKeys
            )
        } catch {
            state = .failed
            return nil
        }
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

    /// Converts a key length in bytes to a ``KeySize`` enum value.
    private func keySizeFromLength(_ length: UInt16) -> KeySize? {
        KeySize(rawValue: Int(length))
    }
}
