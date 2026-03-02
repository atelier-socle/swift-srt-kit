// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore

/// Resolves hostnames to NIO SocketAddress values.
///
/// Provides a clean interface for address resolution without
/// requiring Foundation's networking types.
public enum AddressResolver: Sendable {
    /// Resolve a host:port pair to a SocketAddress.
    ///
    /// - Parameters:
    ///   - host: Hostname or IP address string.
    ///   - port: Port number.
    /// - Returns: Resolved SocketAddress.
    /// - Throws: ``SRTError`` if resolution fails.
    public static func resolve(host: String, port: Int) throws -> SocketAddress {
        do {
            return try SocketAddress.makeAddressResolvingHost(host, port: port)
        } catch {
            throw SRTError.connectionFailed(
                "Failed to resolve address \(host):\(port)"
            )
        }
    }

    /// Check if a string is a valid IPv4 address.
    ///
    /// - Parameter string: The string to check.
    /// - Returns: `true` if the string is a valid IPv4 address.
    public static func isIPv4(_ string: String) -> Bool {
        let parts = string.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let value = UInt16(part) else { return false }
            return value <= 255
        }
    }

    /// Check if a string is a valid IPv6 address.
    ///
    /// - Parameter string: The string to check.
    /// - Returns: `true` if the string is a valid IPv6 address.
    public static func isIPv6(_ string: String) -> Bool {
        string.contains(":")
            && !string.contains(".")  // Exclude IPv4-mapped unless "::"
            || string.hasPrefix("::")
            || (string.contains(":") && string.contains("."))  // IPv4-mapped
    }
}
