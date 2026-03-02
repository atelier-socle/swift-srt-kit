// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("CookieGenerator Tests")
struct CookieGeneratorTests {
    private let defaultSecret: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8]
    private let defaultAddress: SRTPeerAddress = .ipv4(0x7F00_0001)

    @Test("Deterministic output for same inputs")
    func deterministic() {
        let cookie1 = CookieGenerator.generate(
            peerAddress: defaultAddress, peerPort: 1234, secret: defaultSecret, timeBucket: 100
        )
        let cookie2 = CookieGenerator.generate(
            peerAddress: defaultAddress, peerPort: 1234, secret: defaultSecret, timeBucket: 100
        )
        #expect(cookie1 == cookie2)
    }

    @Test("Different peer addresses produce different cookies")
    func differentAddresses() {
        let cookie1 = CookieGenerator.generate(
            peerAddress: .ipv4(0x7F00_0001), peerPort: 1234, secret: defaultSecret, timeBucket: 100
        )
        let cookie2 = CookieGenerator.generate(
            peerAddress: .ipv4(0x0A00_0001), peerPort: 1234, secret: defaultSecret, timeBucket: 100
        )
        #expect(cookie1 != cookie2)
    }

    @Test("Different secrets produce different cookies")
    func differentSecrets() {
        let cookie1 = CookieGenerator.generate(
            peerAddress: defaultAddress, peerPort: 1234, secret: [1, 2, 3, 4], timeBucket: 100
        )
        let cookie2 = CookieGenerator.generate(
            peerAddress: defaultAddress, peerPort: 1234, secret: [5, 6, 7, 8], timeBucket: 100
        )
        #expect(cookie1 != cookie2)
    }

    @Test("Different time buckets produce different cookies")
    func differentTimeBuckets() {
        let cookie1 = CookieGenerator.generate(
            peerAddress: defaultAddress, peerPort: 1234, secret: defaultSecret, timeBucket: 100
        )
        let cookie2 = CookieGenerator.generate(
            peerAddress: defaultAddress, peerPort: 1234, secret: defaultSecret, timeBucket: 101
        )
        #expect(cookie1 != cookie2)
    }

    @Test("Different ports produce different cookies")
    func differentPorts() {
        let cookie1 = CookieGenerator.generate(
            peerAddress: defaultAddress, peerPort: 1234, secret: defaultSecret, timeBucket: 100
        )
        let cookie2 = CookieGenerator.generate(
            peerAddress: defaultAddress, peerPort: 5678, secret: defaultSecret, timeBucket: 100
        )
        #expect(cookie1 != cookie2)
    }

    @Test("Validate returns true for current time bucket")
    func validateCurrentBucket() {
        let cookie = CookieGenerator.generate(
            peerAddress: defaultAddress, peerPort: 1234, secret: defaultSecret, timeBucket: 100
        )
        let valid = CookieGenerator.validate(
            cookie: cookie, peerAddress: defaultAddress, peerPort: 1234,
            secret: defaultSecret, currentTimeBucket: 100
        )
        #expect(valid)
    }

    @Test("Validate returns true for previous time bucket")
    func validatePreviousBucket() {
        let cookie = CookieGenerator.generate(
            peerAddress: defaultAddress, peerPort: 1234, secret: defaultSecret, timeBucket: 99
        )
        let valid = CookieGenerator.validate(
            cookie: cookie, peerAddress: defaultAddress, peerPort: 1234,
            secret: defaultSecret, currentTimeBucket: 100
        )
        #expect(valid)
    }

    @Test("Validate returns false for wrong cookie")
    func validateWrongCookie() {
        let valid = CookieGenerator.validate(
            cookie: 0xDEAD_BEEF, peerAddress: defaultAddress, peerPort: 1234,
            secret: defaultSecret, currentTimeBucket: 100
        )
        #expect(!valid)
    }

    @Test("Validate returns false for expired time bucket")
    func validateExpiredBucket() {
        let cookie = CookieGenerator.generate(
            peerAddress: defaultAddress, peerPort: 1234, secret: defaultSecret, timeBucket: 97
        )
        let valid = CookieGenerator.validate(
            cookie: cookie, peerAddress: defaultAddress, peerPort: 1234,
            secret: defaultSecret, currentTimeBucket: 100
        )
        #expect(!valid)
    }

    @Test("Validate returns false for wrong address")
    func validateWrongAddress() {
        let cookie = CookieGenerator.generate(
            peerAddress: .ipv4(0x7F00_0001), peerPort: 1234,
            secret: defaultSecret, timeBucket: 100
        )
        let valid = CookieGenerator.validate(
            cookie: cookie, peerAddress: .ipv4(0x0A00_0001), peerPort: 1234,
            secret: defaultSecret, currentTimeBucket: 100
        )
        #expect(!valid)
    }

    @Test("Validate returns false for wrong secret")
    func validateWrongSecret() {
        let cookie = CookieGenerator.generate(
            peerAddress: defaultAddress, peerPort: 1234,
            secret: [1, 2, 3, 4], timeBucket: 100
        )
        let valid = CookieGenerator.validate(
            cookie: cookie, peerAddress: defaultAddress, peerPort: 1234,
            secret: [5, 6, 7, 8], currentTimeBucket: 100
        )
        #expect(!valid)
    }

    @Test("Distribution: multiple cookies don't trivially collide")
    func distribution() {
        var cookies = Set<UInt32>()
        for i: UInt32 in 0..<100 {
            let cookie = CookieGenerator.generate(
                peerAddress: .ipv4(i), peerPort: 1234, secret: defaultSecret, timeBucket: 100
            )
            cookies.insert(cookie)
        }
        // At least 95% unique (allow some collisions in 32-bit space)
        #expect(cookies.count >= 95)
    }

    @Test("IPv6 address produces valid cookie")
    func ipv6Cookie() {
        let cookie = CookieGenerator.generate(
            peerAddress: .ipv6(0x2001_0DB8_0000_0000, 0x0000_0000_0000_0001),
            peerPort: 443, secret: defaultSecret, timeBucket: 50
        )
        #expect(cookie != 0)
    }
}
