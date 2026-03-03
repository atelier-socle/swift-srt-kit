// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("AddressResolver Coverage Tests")
struct AddressResolverCoverageTests {

    // MARK: - isIPv4 edge cases

    @Test("isIPv4 rejects 256.1.1.1 (octet > 255)")
    func isIPv4Rejects256() {
        #expect(!AddressResolver.isIPv4("256.1.1.1"))
    }

    @Test("isIPv4 rejects 1.256.1.1")
    func isIPv4RejectsSecondOctet256() {
        #expect(!AddressResolver.isIPv4("1.256.1.1"))
    }

    @Test("isIPv4 rejects 1.1.256.1")
    func isIPv4RejectsThirdOctet256() {
        #expect(!AddressResolver.isIPv4("1.1.256.1"))
    }

    @Test("isIPv4 rejects 1.1.1.256")
    func isIPv4RejectsFourthOctet256() {
        #expect(!AddressResolver.isIPv4("1.1.1.256"))
    }

    @Test("isIPv4 rejects 1.1.1 (only 3 parts)")
    func isIPv4RejectsThreeParts() {
        #expect(!AddressResolver.isIPv4("1.1.1"))
    }

    @Test("isIPv4 rejects 1.1.1.1.1 (5 parts)")
    func isIPv4RejectsFiveParts() {
        #expect(!AddressResolver.isIPv4("1.1.1.1.1"))
    }

    @Test("isIPv4 rejects empty string")
    func isIPv4RejectsEmpty() {
        #expect(!AddressResolver.isIPv4(""))
    }

    @Test("isIPv4 rejects string with empty parts like 1..1.1")
    func isIPv4RejectsEmptyParts() {
        #expect(!AddressResolver.isIPv4("1..1.1"))
    }

    @Test("isIPv4 rejects .1.1.1 (leading dot)")
    func isIPv4RejectsLeadingDot() {
        #expect(!AddressResolver.isIPv4(".1.1.1"))
    }

    @Test("isIPv4 rejects 1.1.1. (trailing dot)")
    func isIPv4RejectsTrailingDot() {
        #expect(!AddressResolver.isIPv4("1.1.1."))
    }

    @Test("isIPv4 rejects non-numeric parts")
    func isIPv4RejectsNonNumeric() {
        #expect(!AddressResolver.isIPv4("a.b.c.d"))
    }

    @Test("isIPv4 rejects negative numbers")
    func isIPv4RejectsNegative() {
        #expect(!AddressResolver.isIPv4("-1.0.0.0"))
    }

    @Test("isIPv4 accepts 0.0.0.0")
    func isIPv4AcceptsAllZeros() {
        #expect(AddressResolver.isIPv4("0.0.0.0"))
    }

    @Test("isIPv4 accepts 255.255.255.255")
    func isIPv4AcceptsAllMax() {
        #expect(AddressResolver.isIPv4("255.255.255.255"))
    }

    @Test("isIPv4 rejects 999.999.999.999")
    func isIPv4RejectsLargeOctets() {
        #expect(!AddressResolver.isIPv4("999.999.999.999"))
    }

    @Test("isIPv4 rejects single number")
    func isIPv4RejectsSingleNumber() {
        #expect(!AddressResolver.isIPv4("12345"))
    }

    @Test("isIPv4 rejects two parts")
    func isIPv4RejectsTwoParts() {
        #expect(!AddressResolver.isIPv4("1.1"))
    }

    // MARK: - isIPv6 edge cases

    @Test("isIPv6 accepts ::1 (loopback)")
    func isIPv6AcceptsLoopback() {
        #expect(AddressResolver.isIPv6("::1"))
    }

    @Test("isIPv6 accepts :: (all-zeros)")
    func isIPv6AcceptsAllZeros() {
        #expect(AddressResolver.isIPv6("::"))
    }

    @Test("isIPv6 accepts fe80::1 (link-local)")
    func isIPv6AcceptsLinkLocal() {
        #expect(AddressResolver.isIPv6("fe80::1"))
    }

    @Test("isIPv6 accepts IPv4-mapped address ::ffff:192.168.1.1")
    func isIPv6AcceptsIPv4Mapped() {
        #expect(AddressResolver.isIPv6("::ffff:192.168.1.1"))
    }

    @Test("isIPv6 accepts full address 2001:db8::1")
    func isIPv6AcceptsFull() {
        #expect(AddressResolver.isIPv6("2001:db8::1"))
    }

    @Test("isIPv6 rejects plain IPv4 192.168.1.1")
    func isIPv6RejectsPlainIPv4() {
        #expect(!AddressResolver.isIPv6("192.168.1.1"))
    }

    @Test("isIPv6 rejects empty string")
    func isIPv6RejectsEmpty() {
        #expect(!AddressResolver.isIPv6(""))
    }

    @Test("isIPv6 rejects plain hostname")
    func isIPv6RejectsHostname() {
        #expect(!AddressResolver.isIPv6("localhost"))
    }

    // MARK: - resolve with invalid hostname

    @Test("resolve with invalid hostname throws SRTError")
    func resolveInvalidHostname() {
        #expect(throws: SRTError.self) {
            _ = try AddressResolver.resolve(
                host: "this.hostname.definitely.does.not.exist.invalid", port: 4200
            )
        }
    }

    @Test("resolve with whitespace-only hostname throws SRTError")
    func resolveWhitespaceHostname() {
        #expect(throws: SRTError.self) {
            _ = try AddressResolver.resolve(host: "!!!invalid host!!!", port: 4200)
        }
    }

    @Test("resolve with valid IPv4 succeeds")
    func resolveValidIPv4() throws {
        let addr = try AddressResolver.resolve(host: "127.0.0.1", port: 9000)
        #expect(addr.port == 9000)
    }

    @Test("resolve with valid IPv6 loopback succeeds")
    func resolveValidIPv6() throws {
        let addr = try AddressResolver.resolve(host: "::1", port: 9001)
        #expect(addr.port == 9001)
    }
}
