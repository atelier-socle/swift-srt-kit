// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("MultiStreamError Tests")
struct MultiStreamErrorTests {
    @Test("duplicateStream description")
    func duplicateStreamDescription() {
        let error = MultiStreamError.duplicateStream(id: 42)
        #expect(error.description == "Duplicate stream ID: 42")
    }

    @Test("streamNotFound description")
    func streamNotFoundDescription() {
        let error = MultiStreamError.streamNotFound(id: 7)
        #expect(error.description == "Stream not found: 7")
    }

    @Test("maxStreamsReached description")
    func maxStreamsReachedDescription() {
        let error = MultiStreamError.maxStreamsReached(max: 16)
        #expect(error.description == "Maximum streams reached: 16")
    }

    @Test("Equatable: same cases are equal")
    func equatableSame() {
        #expect(
            MultiStreamError.duplicateStream(id: 1)
                == MultiStreamError.duplicateStream(id: 1))
    }

    @Test("Equatable: different cases are not equal")
    func equatableDifferent() {
        #expect(
            MultiStreamError.duplicateStream(id: 1)
                != MultiStreamError.streamNotFound(id: 1))
    }
}
