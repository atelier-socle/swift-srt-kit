// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import SRTKit

@Suite("AddressResolver Tests")
struct AddressResolverTests {
    @Test("Resolve IPv4 address string")
    func resolveIPv4() throws {
        let addr = try AddressResolver.resolve(host: "127.0.0.1", port: 4200)
        #expect(addr.port == 4200)
    }

    @Test(
        "Resolve IPv6 address string",
        .tags(.network),
        .enabled(if: !isCI, "IPv6 loopback not available on GitHub Actions Linux runners")
    )
    func resolveIPv6() throws {
        let addr = try AddressResolver.resolve(host: "::1", port: 4200)
        #expect(addr.port == 4200)
    }

    @Test("Resolve wildcard 0.0.0.0")
    func resolveWildcard() throws {
        let addr = try AddressResolver.resolve(host: "0.0.0.0", port: 0)
        #expect(addr.port == 0)
    }

    @Test("Resolve localhost")
    func resolveLocalhost() throws {
        let addr = try AddressResolver.resolve(host: "localhost", port: 4200)
        #expect(addr.port == 4200)
    }

    @Test("isIPv4 returns true for valid IPv4")
    func isIPv4Valid() {
        #expect(AddressResolver.isIPv4("192.168.1.1"))
        #expect(AddressResolver.isIPv4("127.0.0.1"))
        #expect(AddressResolver.isIPv4("0.0.0.0"))
        #expect(AddressResolver.isIPv4("255.255.255.255"))
    }

    @Test("isIPv4 returns false for IPv6")
    func isIPv4InvalidIPv6() {
        #expect(!AddressResolver.isIPv4("::1"))
        #expect(!AddressResolver.isIPv4("fe80::1"))
    }

    @Test("isIPv4 returns false for invalid strings")
    func isIPv4InvalidStrings() {
        #expect(!AddressResolver.isIPv4("localhost"))
        #expect(!AddressResolver.isIPv4("999.999.999.999"))
        #expect(!AddressResolver.isIPv4("1.2.3"))
    }

    @Test("isIPv6 returns true for valid IPv6")
    func isIPv6Valid() {
        #expect(AddressResolver.isIPv6("::1"))
        #expect(AddressResolver.isIPv6("fe80::1"))
        #expect(AddressResolver.isIPv6("::"))
    }

    @Test("isIPv6 returns false for plain IPv4")
    func isIPv6InvalidIPv4() {
        #expect(!AddressResolver.isIPv6("192.168.1.1"))
    }
}
