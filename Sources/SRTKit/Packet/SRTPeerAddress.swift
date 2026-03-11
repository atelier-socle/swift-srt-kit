// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore

/// A peer IP address stored as a 128-bit field in SRT handshake packets.
///
/// IPv4 addresses use the IPv4-mapped IPv6 format: `::ffff:a.b.c.d`.
/// IPv6 addresses are stored natively as two 64-bit values (high and low).
public enum SRTPeerAddress: Sendable, Equatable, Hashable {
    /// An IPv4 address stored as a 32-bit value.
    case ipv4(UInt32)
    /// An IPv6 address stored as two 64-bit values (high bits, low bits).
    case ipv6(UInt64, UInt64)

    /// The size of the encoded peer address in bytes.
    public static let encodedSize = 16

    /// Encodes this address as a 128-bit field in big-endian format.
    ///
    /// IPv4 addresses are encoded in IPv4-mapped IPv6 format:
    /// `[0,0,0,0, 0,0,0,0, 0,0,0xFF,0xFF, a,b,c,d]`
    /// - Parameter buffer: The buffer to write into.
    public func encode(into buffer: inout ByteBuffer) {
        switch self {
        case .ipv4(let addr):
            buffer.writeInteger(UInt64(0))
            buffer.writeInteger(UInt32(0x0000_FFFF))
            buffer.writeInteger(addr)
        case .ipv6(let high, let low):
            buffer.writeInteger(high)
            buffer.writeInteger(low)
        }
    }

    /// Creates a peer address from a NIO `SocketAddress`.
    ///
    /// - Parameter socketAddress: The socket address to convert.
    /// - Returns: The corresponding peer address.
    public static func from(_ socketAddress: SocketAddress) -> SRTPeerAddress {
        switch socketAddress {
        case .v4(let addr):
            let ip = addr.address.sin_addr.s_addr
            let hostOrder = UInt32(bigEndian: ip)
            return .ipv4(hostOrder)
        case .v6(let addr):
            let sin6Addr = addr.address.sin6_addr
            return withUnsafeBytes(of: sin6Addr) { raw in
                var high: UInt64 = 0
                var low: UInt64 = 0
                for i in 0..<8 {
                    high = (high << 8) | UInt64(raw[i])
                }
                for i in 8..<16 {
                    low = (low << 8) | UInt64(raw[i])
                }
                return .ipv6(high, low)
            }
        case .unixDomainSocket:
            return .ipv4(0x7F00_0001)
        }
    }

    /// Decodes a 128-bit peer address from a buffer.
    ///
    /// If the high 80 bits match the IPv4-mapped IPv6 prefix (`::ffff:`),
    /// the address is decoded as IPv4. Otherwise it is decoded as IPv6.
    /// - Parameter buffer: The buffer to read from.
    /// - Returns: The decoded peer address.
    /// - Throws: `SRTError.invalidPacket` if the buffer has insufficient bytes.
    public static func decode(from buffer: inout ByteBuffer) throws -> SRTPeerAddress {
        guard buffer.readableBytes >= encodedSize else {
            throw SRTError.invalidPacket("Peer address requires \(encodedSize) bytes, got \(buffer.readableBytes)")
        }
        guard let high = buffer.readInteger(as: UInt64.self),
            let low = buffer.readInteger(as: UInt64.self)
        else {
            throw SRTError.invalidPacket("Failed to read peer address")
        }

        // Check for IPv4-mapped IPv6: high == 0, low upper 32 bits == 0x0000FFFF
        if high == 0 && (low >> 32) == 0x0000_FFFF {
            let ipv4 = UInt32(low & 0xFFFF_FFFF)
            return .ipv4(ipv4)
        }
        return .ipv6(high, low)
    }
}
