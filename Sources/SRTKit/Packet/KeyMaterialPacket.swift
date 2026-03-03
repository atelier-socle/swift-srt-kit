// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore

/// A Key Material (KM) packet CIF for encryption key exchange.
///
/// Carried as KMREQ/KMRSP handshake extensions during the handshake phase.
/// Contains the cipher configuration, salt, and AES Key Wrap output.
public struct KeyMaterialPacket: Sendable, Equatable {
    /// The expected signature value for KM packets.
    public static let expectedSign: UInt16 = 0x2029

    /// The state of the Stream Encrypting Key (SEK).
    public enum KMState: UInt8, Sendable, Hashable, CaseIterable, CustomStringConvertible {
        /// No SEK available.
        case noSEK = 0
        /// SEK is secured and active.
        case secured = 1
        /// SEK is being secured (in progress).
        case securing = 2
        /// SEK exchange failed.
        case failed = 3
        /// SEK has been verified.
        case verified = 4

        /// A human-readable description of the KM state.
        public var description: String {
            switch self {
            case .noSEK: "noSEK"
            case .secured: "secured"
            case .securing: "securing"
            case .failed: "failed"
            case .verified: "verified"
            }
        }
    }

    /// The cipher type used for encryption.
    public enum CipherType: UInt8, Sendable, Hashable, CaseIterable, CustomStringConvertible {
        /// No encryption.
        case none = 0
        /// AES in Counter mode (AES-CTR).
        case aesCTR = 2
        /// AES in Galois/Counter mode (AES-GCM).
        case aesGCM = 3

        /// A human-readable description of the cipher type.
        public var description: String {
            switch self {
            case .none: "none"
            case .aesCTR: "AES-CTR"
            case .aesGCM: "AES-GCM"
            }
        }
    }

    /// The KM protocol version (always 1).
    public let version: UInt8
    /// The packet type (always 2 for KM).
    public let packetType: UInt8
    /// The KM signature (must be 0x2029).
    public let sign: UInt16
    /// Key-based encryption indicator (0x00=no, 0x01=even, 0x02=odd, 0x03=both).
    public let keyBasedEncryption: UInt8
    /// The cipher type.
    public let cipher: CipherType
    /// Authentication mode (0 for CTR, 1 for GCM).
    public let authentication: UInt8
    /// Stream encapsulation (2 = MPEG-TS/SRT).
    public let streamEncapsulation: UInt8
    /// The 16-byte salt value.
    public let salt: [UInt8]
    /// The key length in bytes (16, 24, or 32).
    public let keyLength: UInt16
    /// The AES Key Wrap output bytes.
    public let wrappedKeys: [UInt8]

    /// Creates a new key material packet.
    ///
    /// - Parameters:
    ///   - version: The KM protocol version.
    ///   - packetType: The packet type.
    ///   - sign: The KM signature.
    ///   - keyBasedEncryption: The key-based encryption indicator.
    ///   - cipher: The cipher type.
    ///   - authentication: The authentication mode.
    ///   - streamEncapsulation: The stream encapsulation type.
    ///   - salt: The 16-byte salt value.
    ///   - keyLength: The key length in bytes.
    ///   - wrappedKeys: The AES Key Wrap output bytes.
    public init(
        version: UInt8 = 1,
        packetType: UInt8 = 2,
        sign: UInt16 = expectedSign,
        keyBasedEncryption: UInt8 = 0x01,
        cipher: CipherType,
        authentication: UInt8 = 0,
        streamEncapsulation: UInt8 = 2,
        salt: [UInt8],
        keyLength: UInt16,
        wrappedKeys: [UInt8]
    ) {
        self.version = version
        self.packetType = packetType
        self.sign = sign
        self.keyBasedEncryption = keyBasedEncryption
        self.cipher = cipher
        self.authentication = authentication
        self.streamEncapsulation = streamEncapsulation
        self.salt = salt
        self.keyLength = keyLength
        self.wrappedKeys = wrappedKeys
    }

    /// Encodes this KM CIF into a buffer.
    ///
    /// Wire format matches libsrt (hcrypt_msg.h):
    /// - Parameter buffer: The buffer to write into.
    public func encode(into buffer: inout ByteBuffer) {
        // Byte 0:      V(4) | PT(4)
        buffer.writeInteger(UInt8((version << 4) | (packetType & 0x0F)))
        // Bytes 1-2:   Sign (0x2029)
        buffer.writeInteger(sign)
        // Byte 3:      KFLGS — Resv(6) | KK(2)
        buffer.writeInteger(keyBasedEncryption & 0x03)
        // Bytes 4-7:   KEKI (Key Encryption Key Index, 0 for passphrase)
        buffer.writeInteger(UInt32(0))
        // Byte 8:      Cipher
        buffer.writeInteger(cipher.rawValue)
        // Byte 9:      Auth
        buffer.writeInteger(authentication)
        // Byte 10:     SE
        buffer.writeInteger(streamEncapsulation)
        // Byte 11:     Reserved
        buffer.writeInteger(UInt8(0))
        // Bytes 12-13: Reserved2
        buffer.writeInteger(UInt16(0))
        // Byte 14:     SLen/4 (salt length in 4-byte words)
        buffer.writeInteger(UInt8(salt.count / 4))
        // Byte 15:     KLen/4 (key length in 4-byte words)
        buffer.writeInteger(UInt8(keyLength / 4))
        // Bytes 16+:   Salt
        buffer.writeBytes(salt)
        // After salt:  Wrapped keys
        buffer.writeBytes(wrappedKeys)
    }

    /// Decodes a KM CIF from a buffer.
    ///
    /// Wire format matches libsrt (hcrypt_msg.h).
    /// - Parameters:
    ///   - buffer: The buffer to read from.
    ///   - cifLength: The total CIF length in bytes.
    /// - Returns: The decoded key material packet.
    /// - Throws: `SRTError.invalidPacket` if the buffer contains invalid data.
    public static func decode(from buffer: inout ByteBuffer, cifLength: Int) throws -> KeyMaterialPacket {
        guard cifLength >= 16 else {
            throw SRTError.invalidPacket("KM CIF too small: \(cifLength) bytes")
        }
        // Byte 0: V|PT
        guard let byte0 = buffer.readInteger(as: UInt8.self),
            // Bytes 1-2: Sign
            let signVal = buffer.readInteger(as: UInt16.self),
            // Byte 3: KFLGS (Resv(6)|KK(2))
            let kflgs = buffer.readInteger(as: UInt8.self),
            // Bytes 4-7: KEKI
            buffer.readInteger(as: UInt32.self) != nil,
            // Byte 8: Cipher
            let cipherRaw = buffer.readInteger(as: UInt8.self),
            // Byte 9: Auth
            let auth = buffer.readInteger(as: UInt8.self),
            // Byte 10: SE
            let se = buffer.readInteger(as: UInt8.self),
            // Byte 11: Reserved
            buffer.readInteger(as: UInt8.self) != nil,
            // Bytes 12-13: Reserved2
            buffer.readInteger(as: UInt16.self) != nil,
            // Byte 14: SLen/4
            let saltLenByte = buffer.readInteger(as: UInt8.self),
            // Byte 15: KLen/4
            let keyLenByte = buffer.readInteger(as: UInt8.self)
        else {
            throw SRTError.invalidPacket("Failed to read KM header")
        }

        let ver = (byte0 >> 4) & 0x0F
        let pt = byte0 & 0x0F
        let ke = kflgs & 0x03

        guard let cipherType = CipherType(rawValue: cipherRaw) else {
            throw SRTError.invalidPacket("Unknown cipher type: \(cipherRaw)")
        }

        let saltLen = Int(saltLenByte) * 4
        let keyLen = UInt16(keyLenByte) * 4

        guard buffer.readableBytes >= saltLen else {
            throw SRTError.invalidPacket("Not enough bytes for salt")
        }
        guard let saltBytes = buffer.readBytes(length: saltLen) else {
            throw SRTError.invalidPacket("Failed to read salt")
        }

        let wrappedKeysLen = buffer.readableBytes
        let wrappedKeys: [UInt8]
        if wrappedKeysLen > 0 {
            guard let keys = buffer.readBytes(length: wrappedKeysLen) else {
                throw SRTError.invalidPacket("Failed to read wrapped keys")
            }
            wrappedKeys = keys
        } else {
            wrappedKeys = []
        }

        return KeyMaterialPacket(
            version: ver,
            packetType: pt,
            sign: signVal,
            keyBasedEncryption: ke,
            cipher: cipherType,
            authentication: auth,
            streamEncapsulation: se,
            salt: saltBytes,
            keyLength: keyLen,
            wrappedKeys: wrappedKeys
        )
    }
}
