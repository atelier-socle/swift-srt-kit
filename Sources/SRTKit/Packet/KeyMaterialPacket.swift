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
    /// - Parameter buffer: The buffer to write into.
    public func encode(into buffer: inout ByteBuffer) {
        // KM wire format:
        // Byte 0:      V(4) | PT(4)
        // Bytes 1-2:   sign (0x2029)
        // Byte 3:      KE(4) | cipher(4)
        // Byte 4:      auth(4) | SE(4)
        // Byte 5:      reserved (0)
        // Bytes 6-7:   salt length in 32-bit words
        // Bytes 8-23:  salt (16 bytes)
        // Bytes 24-25: key length in 32-bit words
        // Bytes 26+:   wrapped keys
        buffer.writeInteger(UInt8((version << 4) | (packetType & 0x0F)))
        buffer.writeInteger(sign)
        buffer.writeInteger(UInt8((keyBasedEncryption << 4) | (cipher.rawValue & 0x0F)))
        buffer.writeInteger(UInt8((authentication << 4) | (streamEncapsulation & 0x0F)))
        buffer.writeInteger(UInt8(0))
        buffer.writeInteger(UInt16(UInt16(salt.count) / 4))
        buffer.writeBytes(salt)
        buffer.writeInteger(UInt16(keyLength / 4))
        buffer.writeBytes(wrappedKeys)
    }

    /// Decodes a KM CIF from a buffer.
    ///
    /// - Parameters:
    ///   - buffer: The buffer to read from.
    ///   - cifLength: The total CIF length in bytes.
    /// - Returns: The decoded key material packet.
    /// - Throws: `SRTError.invalidPacket` if the buffer contains invalid data.
    public static func decode(from buffer: inout ByteBuffer, cifLength: Int) throws -> KeyMaterialPacket {
        guard cifLength >= 8 else {
            throw SRTError.invalidPacket("KM CIF too small: \(cifLength) bytes")
        }
        guard let byte0 = buffer.readInteger(as: UInt8.self),
            let signVal = buffer.readInteger(as: UInt16.self),
            let byte3 = buffer.readInteger(as: UInt8.self),
            let byte4 = buffer.readInteger(as: UInt8.self),
            buffer.readInteger(as: UInt8.self) != nil,  // reserved
            let saltLenWords = buffer.readInteger(as: UInt16.self)
        else {
            throw SRTError.invalidPacket("Failed to read KM header")
        }

        let ver = (byte0 >> 4) & 0x0F
        let pt = byte0 & 0x0F
        let ke = (byte3 >> 4) & 0x0F
        let cipherRaw = byte3 & 0x0F
        let auth = (byte4 >> 4) & 0x0F
        let se = byte4 & 0x0F

        guard let cipherType = CipherType(rawValue: cipherRaw) else {
            throw SRTError.invalidPacket("Unknown cipher type: \(cipherRaw)")
        }

        let saltLen = Int(saltLenWords) * 4
        guard buffer.readableBytes >= saltLen else {
            throw SRTError.invalidPacket("Not enough bytes for salt")
        }
        guard let saltBytes = buffer.readBytes(length: saltLen) else {
            throw SRTError.invalidPacket("Failed to read salt")
        }

        guard let keyLenWords = buffer.readInteger(as: UInt16.self) else {
            throw SRTError.invalidPacket("Failed to read key length")
        }
        let keyLen = UInt16(keyLenWords) * 4

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
