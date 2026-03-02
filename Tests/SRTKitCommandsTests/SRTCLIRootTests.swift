// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKitCommands

@Suite("SRTCLIRoot Tests")
struct SRTCLIRootTests {
    @Test("Command name is srt-cli")
    func commandName() {
        #expect(SRTCLIRoot.configuration.commandName == "srt-cli")
    }

    @Test("Version is set")
    func versionIsSet() {
        #expect(SRTCLIRoot.configuration.version == "0.1.0")
    }

    @Test("Abstract is set")
    func abstractIsSet() {
        let abstract = SRTCLIRoot.configuration.abstract
        #expect(!abstract.isEmpty)
    }

    @Test("Can create instance")
    func canCreateInstance() {
        let root = SRTCLIRoot()
        #expect(type(of: root) == SRTCLIRoot.self)
    }
}
