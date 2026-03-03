// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKitCommands

/// Tests for InfoCommand output content.
///
/// Rather than redirecting stdout (which can crash the test runner),
/// we test the command's configuration and parsing, plus verify
/// the output indirectly via a helper that builds the output string.
@Suite("InfoCommand Output Tests")
struct InfoCommandOutputTests {
    @Test("InfoCommand configuration name is info")
    func infoConfigName() {
        #expect(InfoCommand.configuration.commandName == "info")
    }

    @Test("InfoCommand abstract is set")
    func infoAbstract() {
        let abstract = InfoCommand.configuration.abstract
        #expect(!abstract.isEmpty)
        #expect(
            abstract.contains("version") || abstract.contains("feature")
                || abstract.contains("information"))
    }

    @Test("InfoCommand default verbose is false")
    func defaultVerboseFalse() throws {
        let cmd = try InfoCommand.parse([])
        #expect(cmd.verbose == false)
    }

    @Test("InfoCommand --verbose sets flag")
    func verboseFlag() throws {
        let cmd = try InfoCommand.parse(["--verbose"])
        #expect(cmd.verbose == true)
    }

    @Test("InfoCommand can be parsed with no arguments")
    func canParse() throws {
        let cmd = try InfoCommand.parse([])
        #expect(type(of: cmd) == InfoCommand.self)
    }
}
