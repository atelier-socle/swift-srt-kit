// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("ProbeError Tests")
struct ProbeErrorTests {
    @Test("Each error has meaningful description")
    func descriptions() {
        #expect(
            ProbeError.probeInProgress.description
                == "Probe already in progress")
        #expect(ProbeError.noSteps.description == "No steps configured")
        #expect(ProbeError.probeNotStarted.description == "Probe not started")
        #expect(
            ProbeError.immediatelySaturated.description
                == "All steps saturated immediately")
    }

    @Test("Equatable: same cases are equal")
    func equatableSame() {
        #expect(ProbeError.probeInProgress == ProbeError.probeInProgress)
        #expect(ProbeError.noSteps == ProbeError.noSteps)
    }

    @Test("Equatable: different cases are not equal")
    func equatableDifferent() {
        #expect(ProbeError.probeInProgress != ProbeError.noSteps)
        #expect(ProbeError.probeNotStarted != ProbeError.immediatelySaturated)
    }
}
