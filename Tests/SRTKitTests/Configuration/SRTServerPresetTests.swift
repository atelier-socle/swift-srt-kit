// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTServerPreset Tests")
struct SRTServerPresetTests {
    // MARK: - Individual presets

    @Test("awsMediaConnect: latency=1_000_000, usesStreamID=true")
    func awsMediaConnect() {
        let options = SRTServerPreset.awsMediaConnect.socketOptions()
        #expect(options.latency == 1_000_000)
        #expect(options.sendBufferSize == 16_384)
        #expect(SRTServerPreset.awsMediaConnect.usesStreamID)
        #expect(SRTServerPreset.awsMediaConnect.requiresEncryption)
    }

    @Test("haivisionHub: keySize=.aes256, usesStreamID=true")
    func haivisionHub() {
        let options = SRTServerPreset.haivisionHub.socketOptions()
        #expect(options.keySize == .aes256)
        #expect(SRTServerPreset.haivisionHub.usesStreamID)
        #expect(SRTServerPreset.haivisionHub.requiresEncryption)
    }

    @Test("obsStudio: usesStreamID=false")
    func obsStudio() {
        #expect(!SRTServerPreset.obsStudio.usesStreamID)
        #expect(!SRTServerPreset.obsStudio.requiresEncryption)
        #expect(SRTServerPreset.obsStudio.streamIDFormat == nil)
    }

    @Test("vmix: usesStreamID=false")
    func vmix() {
        #expect(!SRTServerPreset.vmix.usesStreamID)
        #expect(!SRTServerPreset.vmix.requiresEncryption)
        #expect(SRTServerPreset.vmix.streamIDFormat == nil)
    }

    @Test("nimbleStreamer: latency=500_000, usesStreamID=true")
    func nimbleStreamer() {
        let options = SRTServerPreset.nimbleStreamer.socketOptions()
        #expect(options.latency == 500_000)
        #expect(SRTServerPreset.nimbleStreamer.usesStreamID)
    }

    @Test("srsServer: defaultPort=10080, usesStreamID=true")
    func srsServer() {
        #expect(SRTServerPreset.srsServer.defaultPort == 10080)
        #expect(SRTServerPreset.srsServer.usesStreamID)
    }

    @Test("wowzaStreaming: latency=500_000, defaultPort=9710")
    func wowzaStreaming() {
        let options = SRTServerPreset.wowzaStreaming.socketOptions()
        #expect(options.latency == 500_000)
        #expect(SRTServerPreset.wowzaStreaming.defaultPort == 9710)
        #expect(SRTServerPreset.wowzaStreaming.requiresEncryption)
    }

    // MARK: - Configuration generation

    @Test("configuration with resource includes StreamID when usesStreamID")
    func configWithStreamID() {
        let config = SRTServerPreset.awsMediaConnect.configuration(
            host: "ingest.aws.com", resource: "stream123")
        #expect(config.accessControl != nil)
        #expect(config.accessControl?.resource == "stream123")
    }

    @Test("configuration omits StreamID when !usesStreamID")
    func configOmitsStreamID() {
        let config = SRTServerPreset.obsStudio.configuration(
            host: "192.168.1.1", resource: "ignored")
        #expect(config.accessControl == nil)
    }

    @Test("configuration uses default port when port is nil")
    func configDefaultPort() {
        let config = SRTServerPreset.srsServer.configuration(
            host: "srs.example.com")
        #expect(config.port == 10080)
    }

    @Test("configuration uses custom port when provided")
    func configCustomPort() {
        let config = SRTServerPreset.srsServer.configuration(
            host: "srs.example.com", port: 8080)
        #expect(config.port == 8080)
    }

    // MARK: - CaseIterable

    @Test("CaseIterable lists all 7 presets")
    func caseIterableCount() {
        #expect(SRTServerPreset.allCases.count == 7)
    }

    @Test("All presets have defaultPort > 0")
    func allDefaultPortsPositive() {
        for preset in SRTServerPreset.allCases {
            #expect(preset.defaultPort > 0)
        }
    }

    @Test("All presets have non-empty description")
    func allDescriptionsNonEmpty() {
        for preset in SRTServerPreset.allCases {
            #expect(!preset.description.isEmpty)
        }
    }

    @Test("Presets with usesStreamID have non-nil streamIDFormat")
    func streamIDFormatConsistency() {
        for preset in SRTServerPreset.allCases {
            if preset.usesStreamID {
                #expect(preset.streamIDFormat != nil)
            } else {
                #expect(preset.streamIDFormat == nil)
            }
        }
    }

    @Test("socketOptions matches apply(to:)")
    func socketOptionsMatchesApply() {
        for preset in SRTServerPreset.allCases {
            let fromSocketOptions = preset.socketOptions()
            var fromApply = SRTSocketOptions()
            preset.apply(to: &fromApply)
            #expect(fromSocketOptions == fromApply)
        }
    }
}
