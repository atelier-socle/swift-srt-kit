// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKitCommands

@Suite("InfoCommand Coverage Tests")
struct InfoCommandCoverageTests {

    @Test("InfoCommand run without verbose prints basic info")
    func runWithoutVerbose() async throws {
        var cmd = try InfoCommand.parse([])
        try await cmd.run()
    }

    @Test("InfoCommand run with verbose prints presets")
    func runWithVerbose() async throws {
        var cmd = try InfoCommand.parse(["--verbose"])
        try await cmd.run()
    }
}
