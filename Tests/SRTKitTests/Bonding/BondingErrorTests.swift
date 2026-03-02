// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("BondingError Tests")
struct BondingErrorTests {
    @Test("Each error has meaningful description")
    func allDescriptionsNonEmpty() {
        let errors: [BondingError] = [
            .groupFull(maxMembers: 8),
            .memberNotFound(id: 42),
            .invalidStatusTransition(from: .idle, to: .stable),
            .noActiveMembers,
            .duplicateMember(id: 1)
        ]
        for error in errors {
            #expect(!error.description.isEmpty)
        }
    }

    @Test("Equatable works")
    func equatable() {
        #expect(BondingError.noActiveMembers == BondingError.noActiveMembers)
        #expect(
            BondingError.groupFull(maxMembers: 8)
                == BondingError.groupFull(maxMembers: 8))
        #expect(
            BondingError.groupFull(maxMembers: 8)
                != BondingError.groupFull(maxMembers: 4))
    }

    @Test("groupFull includes maxMembers in description")
    func groupFullDescription() {
        let error = BondingError.groupFull(maxMembers: 8)
        #expect(error.description.contains("8"))
    }

    @Test("memberNotFound includes ID in description")
    func memberNotFoundDescription() {
        let error = BondingError.memberNotFound(id: 42)
        #expect(error.description.contains("42"))
    }

    @Test("invalidStatusTransition includes from/to")
    func invalidTransitionDescription() {
        let error = BondingError.invalidStatusTransition(
            from: .idle, to: .stable)
        #expect(error.description.contains("idle"))
        #expect(error.description.contains("stable"))
    }
}
