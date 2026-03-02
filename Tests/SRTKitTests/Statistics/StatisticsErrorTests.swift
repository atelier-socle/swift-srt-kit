// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("StatisticsError Tests")
struct StatisticsErrorTests {
    @Test("Each error has meaningful description")
    func allDescriptionsNonEmpty() {
        let errors: [StatisticsError] = [
            .invalidMetricValue(name: "rtt", value: "-1"),
            .exportFormatError("bad format")
        ]
        for error in errors {
            #expect(!error.description.isEmpty)
        }
    }

    @Test("invalidMetricValue includes name and value in description")
    func invalidMetricValueDescription() {
        let error = StatisticsError.invalidMetricValue(name: "rtt", value: "-1")
        #expect(error.description.contains("rtt"))
        #expect(error.description.contains("-1"))
    }

    @Test("exportFormatError includes detail in description")
    func exportFormatErrorDescription() {
        let error = StatisticsError.exportFormatError("bad format")
        #expect(error.description.contains("bad format"))
    }

    @Test("Equatable works")
    func equatable() {
        #expect(
            StatisticsError.exportFormatError("a")
                == StatisticsError.exportFormatError("a"))
        #expect(
            StatisticsError.exportFormatError("a")
                != StatisticsError.exportFormatError("b"))
        #expect(
            StatisticsError.invalidMetricValue(name: "x", value: "1")
                == StatisticsError.invalidMetricValue(name: "x", value: "1"))
    }
}
