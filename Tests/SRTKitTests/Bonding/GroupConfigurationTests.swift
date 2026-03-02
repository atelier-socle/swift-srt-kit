// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("GroupConfiguration Tests")
struct GroupConfigurationTests {
    @Test("Default stabilityTimeout is 40_000")
    func defaultStabilityTimeout() {
        let config = GroupConfiguration(mode: .broadcast)
        #expect(config.stabilityTimeout == 40_000)
    }

    @Test("Default peerLatency is 120_000")
    func defaultPeerLatency() {
        let config = GroupConfiguration(mode: .broadcast)
        #expect(config.peerLatency == 120_000)
    }

    @Test("effectiveStabilityTimeout = max(peerLatency, stabilityTimeout)")
    func effectiveStabilityTimeoutDefault() {
        let config = GroupConfiguration(mode: .mainBackup)
        #expect(config.effectiveStabilityTimeout == 120_000)
    }

    @Test("effectiveStabilityTimeout with high stabilityTimeout")
    func effectiveStabilityTimeoutHighTimeout() {
        let config = GroupConfiguration(
            mode: .mainBackup, stabilityTimeout: 200_000,
            peerLatency: 120_000)
        #expect(config.effectiveStabilityTimeout == 200_000)
    }

    @Test("Equatable: same config equal, different mode not equal")
    func equatable() {
        let a = GroupConfiguration(mode: .broadcast)
        let b = GroupConfiguration(mode: .broadcast)
        let c = GroupConfiguration(mode: .balancing)
        #expect(a == b)
        #expect(a != c)
    }

    @Test("Default maxMembers is 8")
    func defaultMaxMembers() {
        let config = GroupConfiguration(mode: .broadcast)
        #expect(config.maxMembers == 8)
    }
}
