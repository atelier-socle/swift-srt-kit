// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("MultiCallerError Tests")
struct MultiCallerErrorTests {
    @Test("duplicateDestination description")
    func duplicateDescription() {
        let error = MultiCallerError.duplicateDestination(id: "d1")
        #expect(error.description == "Duplicate destination: d1")
    }

    @Test("destinationNotFound description")
    func notFoundDescription() {
        let error = MultiCallerError.destinationNotFound(id: "unknown")
        #expect(error.description == "Destination not found: unknown")
    }

    @Test("allDestinationsFailed description")
    func allFailedDescription() {
        let error = MultiCallerError.allDestinationsFailed
        #expect(error.description == "All destinations failed")
    }

    @Test("maxDestinationsReached description")
    func maxReachedDescription() {
        let error = MultiCallerError.maxDestinationsReached(max: 8)
        #expect(error.description == "Maximum destinations reached: 8")
    }

    @Test("Equatable: same cases are equal")
    func equatableSame() {
        #expect(
            MultiCallerError.duplicateDestination(id: "a")
                == MultiCallerError.duplicateDestination(id: "a"))
        #expect(
            MultiCallerError.allDestinationsFailed
                == MultiCallerError.allDestinationsFailed)
    }

    @Test("Equatable: different cases are not equal")
    func equatableDifferent() {
        #expect(
            MultiCallerError.duplicateDestination(id: "a")
                != MultiCallerError.destinationNotFound(id: "a"))
    }
}
