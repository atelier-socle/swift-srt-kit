// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("LinkStatus Tests")
struct LinkStatusTests {
    @Test("All statuses have correct string description")
    func allDescriptions() {
        for status in LinkStatus.allCases {
            #expect(!status.description.isEmpty)
            #expect(status.description == status.rawValue)
        }
    }

    @Test("isActive true for freshActivated and stable only")
    func isActive() {
        #expect(!LinkStatus.pending.isActive)
        #expect(!LinkStatus.idle.isActive)
        #expect(LinkStatus.freshActivated.isActive)
        #expect(LinkStatus.stable.isActive)
        #expect(!LinkStatus.unstable.isActive)
        #expect(!LinkStatus.broken.isActive)
    }

    @Test("isTerminal true for broken only")
    func isTerminal() {
        for status in LinkStatus.allCases {
            if status == .broken {
                #expect(status.isTerminal)
            } else {
                #expect(!status.isTerminal)
            }
        }
    }

    @Test("Valid transitions from pending: idle, broken")
    func pendingTransitions() {
        #expect(LinkStatus.pending.validTransitions == [.idle, .broken])
    }

    @Test("Valid transitions from idle: freshActivated, broken")
    func idleTransitions() {
        #expect(
            LinkStatus.idle.validTransitions == [.freshActivated, .broken])
    }

    @Test("Valid transitions from freshActivated: stable, unstable, broken")
    func freshActivatedTransitions() {
        #expect(
            LinkStatus.freshActivated.validTransitions == [
                .stable, .unstable, .broken
            ])
    }

    @Test("Valid transitions from stable: unstable, broken")
    func stableTransitions() {
        #expect(
            LinkStatus.stable.validTransitions == [.unstable, .broken])
    }

    @Test("Valid transitions from unstable: stable, broken")
    func unstableTransitions() {
        #expect(
            LinkStatus.unstable.validTransitions == [.stable, .broken])
    }

    @Test("No transitions from broken (terminal)")
    func brokenTransitions() {
        #expect(LinkStatus.broken.validTransitions.isEmpty)
    }

    @Test("CaseIterable lists all 6 statuses")
    func caseIterable() {
        #expect(LinkStatus.allCases.count == 6)
    }
}
