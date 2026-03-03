// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit
@testable import SRTKitCommands

@Suite("PresetParser Tests")
struct PresetParserTests {
    // MARK: - parsePreset

    @Test("lowLatency preset")
    func parseLowLatency() throws {
        let preset = try PresetParser.parsePreset("lowLatency")
        #expect(preset == .lowLatency)
    }

    @Test("balanced preset")
    func parseBalanced() throws {
        let preset = try PresetParser.parsePreset("balanced")
        #expect(preset == .balanced)
    }

    @Test("reliable preset")
    func parseReliable() throws {
        let preset = try PresetParser.parsePreset("reliable")
        #expect(preset == .reliable)
    }

    @Test("highBandwidth preset")
    func parseHighBandwidth() throws {
        let preset = try PresetParser.parsePreset("highBandwidth")
        #expect(preset == .highBandwidth)
    }

    @Test("broadcast preset")
    func parseBroadcast() throws {
        let preset = try PresetParser.parsePreset("broadcast")
        #expect(preset == .broadcast)
    }

    @Test("fileTransfer preset")
    func parseFileTransfer() throws {
        let preset = try PresetParser.parsePreset("fileTransfer")
        #expect(preset == .fileTransfer)
    }

    @Test("invalid preset throws")
    func parseInvalid() {
        #expect(throws: CLIError.self) {
            _ = try PresetParser.parsePreset("invalid")
        }
    }

    @Test("case insensitive: LowLatency")
    func caseInsensitive() throws {
        let preset = try PresetParser.parsePreset("LowLatency")
        #expect(preset == .lowLatency)
    }

    // MARK: - parseProbeConfiguration

    @Test("quick probe configuration")
    func parseQuickProbe() throws {
        let config = try PresetParser.parseProbeConfiguration("quick")
        #expect(config == .quick)
    }

    @Test("standard probe configuration")
    func parseStandardProbe() throws {
        let config = try PresetParser.parseProbeConfiguration("standard")
        #expect(config == .standard)
    }

    @Test("thorough probe configuration")
    func parseThoroughProbe() throws {
        let config = try PresetParser.parseProbeConfiguration("thorough")
        #expect(config == .thorough)
    }

    @Test("invalid probe mode throws")
    func parseInvalidProbe() {
        #expect(throws: CLIError.self) {
            _ = try PresetParser.parseProbeConfiguration("invalid")
        }
    }

    // MARK: - parseTargetQuality

    @Test("quality target")
    func parseQuality() throws {
        let tq = try PresetParser.parseTargetQuality("quality")
        #expect(tq == .quality)
    }

    @Test("balanced target")
    func parseBalancedTarget() throws {
        let tq = try PresetParser.parseTargetQuality("balanced")
        #expect(tq == .balanced)
    }

    @Test("lowLatency target")
    func parseLowLatencyTarget() throws {
        let tq = try PresetParser.parseTargetQuality("lowLatency")
        #expect(tq == .lowLatency)
    }

    @Test("invalid target quality throws")
    func parseInvalidTarget() {
        #expect(throws: CLIError.self) {
            _ = try PresetParser.parseTargetQuality("invalid")
        }
    }
}
