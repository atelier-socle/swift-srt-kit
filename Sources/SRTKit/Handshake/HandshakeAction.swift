// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Action produced by the handshake state machine.
///
/// The state machine is pure logic that produces actions — it does not perform I/O.
/// The caller of the state machine is responsible for executing these actions.
public enum HandshakeAction: Sendable {
    /// Send this handshake packet to the peer, with optional extensions.
    case sendPacket(HandshakePacket, extensions: [HandshakeExtensionData])
    /// The handshake completed successfully with the given result.
    case completed(HandshakeResult)
    /// The handshake failed with the given error.
    case error(SRTError)
    /// Wait for a response from the peer, with a timeout in milliseconds.
    case waitForResponse(timeoutMs: UInt64)
}

/// Wrapper for extension data to send with a handshake packet.
///
/// Each case corresponds to a specific SRT handshake extension type.
public enum HandshakeExtensionData: Sendable, Equatable {
    /// SRT handshake request extension (HSREQ).
    case hsreq(SRTHandshakeExtension)
    /// SRT handshake response extension (HSRSP).
    case hsrsp(SRTHandshakeExtension)
    /// Key material request extension (KMREQ).
    case kmreq(KeyMaterialPacket)
    /// Key material response extension (KMRSP).
    case kmrsp(KeyMaterialPacket)
    /// Stream ID extension (SID).
    case streamID(String)
}
