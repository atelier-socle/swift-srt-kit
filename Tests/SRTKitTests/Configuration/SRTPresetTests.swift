// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTPreset Tests")
struct SRTPresetTests {
    // MARK: - Preset options

    @Test("lowLatency: latency=20_000, tlpktdrop=true, CC=live")
    func lowLatencyOptions() {
        let options = SRTPreset.lowLatency.socketOptions()
        #expect(options.latency == 20_000)
        #expect(options.tlpktdrop)
        #expect(options.congestionControl == "live")
        #expect(options.transmissionType == .live)
    }

    @Test("balanced: latency=120_000, tlpktdrop=true")
    func balancedOptions() {
        let options = SRTPreset.balanced.socketOptions()
        #expect(options.latency == 120_000)
        #expect(options.tlpktdrop)
        #expect(options.congestionControl == "live")
    }

    @Test("reliable: latency=500_000, tlpktdrop=false")
    func reliableOptions() {
        let options = SRTPreset.reliable.socketOptions()
        #expect(options.latency == 500_000)
        #expect(!options.tlpktdrop)
        #expect(options.congestionControl == "live")
    }

    @Test("highBandwidth: larger buffers, live CC")
    func highBandwidthOptions() {
        let options = SRTPreset.highBandwidth.socketOptions()
        #expect(options.latency == 120_000)
        #expect(options.tlpktdrop)
        #expect(options.sendBufferSize == 16_384)
        #expect(options.receiveBufferSize == 16_384)
        #expect(options.transmissionType == .live)
    }

    @Test("broadcast: overheadPercent=25")
    func broadcastOptions() {
        let options = SRTPreset.broadcast.socketOptions()
        #expect(options.overheadPercent == 25)
        #expect(options.tlpktdrop)
        #expect(options.transmissionType == .live)
    }

    @Test("fileTransfer: transmissionType=.file, tsbpd=false, CC=file")
    func fileTransferOptions() {
        let options = SRTPreset.fileTransfer.socketOptions()
        #expect(options.transmissionType == .file)
        #expect(!options.tsbpd)
        #expect(!options.tlpktdrop)
        #expect(options.congestionControl == "file")
        #expect(options.latency == 0)
    }

    // MARK: - Configuration generation

    @Test("preset.configuration produces valid SRTConfiguration")
    func configurationGeneration() throws {
        let config = SRTPreset.balanced.configuration(
            host: "10.0.0.1", port: 9000)
        #expect(config.host == "10.0.0.1")
        #expect(config.port == 9000)
        #expect(config.mode == .caller)
        try config.validate()
    }

    @Test("preset.socketOptions matches apply(to:)")
    func socketOptionsMatchesApply() {
        for preset in SRTPreset.allCases {
            let fromSocketOptions = preset.socketOptions()
            var fromApply = SRTSocketOptions()
            preset.apply(to: &fromApply)
            #expect(fromSocketOptions == fromApply)
        }
    }

    // MARK: - CaseIterable

    @Test("CaseIterable lists all 6 presets")
    func caseIterableCount() {
        #expect(SRTPreset.allCases.count == 6)
    }

    @Test("All presets have non-empty description")
    func allDescriptionsNonEmpty() {
        for preset in SRTPreset.allCases {
            #expect(!preset.description.isEmpty)
        }
    }

    @Test("All presets have valid raw values")
    func allRawValues() {
        for preset in SRTPreset.allCases {
            #expect(!preset.rawValue.isEmpty)
        }
    }

    @Test("Configuration with custom mode")
    func configurationCustomMode() {
        let config = SRTPreset.lowLatency.configuration(
            host: "0.0.0.0", port: 5000, mode: .listener)
        #expect(config.mode == .listener)
        #expect(config.options.latency == 20_000)
    }
}
