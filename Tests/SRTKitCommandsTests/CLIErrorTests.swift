// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKitCommands

@Suite("CLIError Tests")
struct CLIErrorTests {
    @Test("invalidArgument has meaningful description")
    func invalidArgument() {
        let error = CLIError.invalidArgument(
            name: "port", value: "abc", expected: "integer")
        #expect(error.description.contains("port"))
        #expect(error.description.contains("abc"))
        #expect(error.description.contains("integer"))
    }

    @Test("fileNotFound includes path")
    func fileNotFound() {
        let error = CLIError.fileNotFound(path: "/tmp/missing.ts")
        #expect(error.description.contains("/tmp/missing.ts"))
    }

    @Test("invalidPreset includes name")
    func invalidPreset() {
        let error = CLIError.invalidPreset(name: "turbo")
        #expect(error.description.contains("turbo"))
    }

    @Test("invalidProbeMode includes name")
    func invalidProbeMode() {
        let error = CLIError.invalidProbeMode(name: "ultra")
        #expect(error.description.contains("ultra"))
    }

    @Test("invalidTargetQuality includes name")
    func invalidTargetQuality() {
        let error = CLIError.invalidTargetQuality(name: "extreme")
        #expect(error.description.contains("extreme"))
    }

    @Test("connectionFailed includes reason")
    func connectionFailed() {
        let error = CLIError.connectionFailed(reason: "timeout")
        #expect(error.description.contains("timeout"))
    }
}
