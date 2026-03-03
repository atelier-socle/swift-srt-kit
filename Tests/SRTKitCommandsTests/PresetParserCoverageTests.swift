// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit
@testable import SRTKitCommands

@Suite("PresetParser Server Preset Coverage Tests")
struct PresetParserServerPresetTests {
    @Test("awsMediaConnect server preset")
    func parseAWSMediaConnect() throws {
        let preset = try PresetParser.parseServerPreset("awsMediaConnect")
        #expect(preset == .awsMediaConnect)
    }

    @Test("nimbleStreamer server preset")
    func parseNimbleStreamer() throws {
        let preset = try PresetParser.parseServerPreset("nimbleStreamer")
        #expect(preset == .nimbleStreamer)
    }

    @Test("haivisionHub server preset")
    func parseHaivisionHub() throws {
        let preset = try PresetParser.parseServerPreset("haivisionHub")
        #expect(preset == .haivisionHub)
    }

    @Test("vmix server preset")
    func parseVmix() throws {
        let preset = try PresetParser.parseServerPreset("vmix")
        #expect(preset == .vmix)
    }

    @Test("obsStudio server preset")
    func parseOBSStudio() throws {
        let preset = try PresetParser.parseServerPreset("obsStudio")
        #expect(preset == .obsStudio)
    }

    @Test("srsServer server preset")
    func parseSRSServer() throws {
        let preset = try PresetParser.parseServerPreset("srsServer")
        #expect(preset == .srsServer)
    }

    @Test("wowzaStreaming server preset")
    func parseWowzaStreaming() throws {
        let preset = try PresetParser.parseServerPreset("wowzaStreaming")
        #expect(preset == .wowzaStreaming)
    }

    @Test("invalid server preset throws")
    func parseInvalidServerPreset() {
        #expect(throws: CLIError.self) {
            _ = try PresetParser.parseServerPreset("unknownServer")
        }
    }

    @Test("case insensitive server preset")
    func caseInsensitiveServerPreset() throws {
        let preset = try PresetParser.parseServerPreset("AWSMediaConnect")
        #expect(preset == .awsMediaConnect)
    }
}
