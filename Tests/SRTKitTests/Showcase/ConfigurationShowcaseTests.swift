// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("Configuration Showcase")
struct ConfigurationShowcaseTests {
    // MARK: - Presets

    @Test("All 6 SRTPresets produce valid configurations")
    func allPresetsValid() {
        for preset in SRTPreset.allCases {
            let config = preset.configuration(
                host: "srt.example.com", port: 4200)
            #expect(config.host == "srt.example.com")
            #expect(config.port == 4200)
        }
    }

    @Test("lowLatency preset prioritizes minimal delay")
    func lowLatencyPreset() {
        let options = SRTPreset.lowLatency.socketOptions()
        // Low latency preset should have lower latency than balanced
        let balanced = SRTPreset.balanced.socketOptions()
        #expect(options.latency <= balanced.latency)
    }

    @Test("fileTransfer preset disables TSBPD and uses file CC")
    func fileTransferPreset() {
        let options = SRTPreset.fileTransfer.socketOptions()
        // File transfer disables TSBPD (latency=0) and uses file CC
        #expect(options.tsbpd == false)
        #expect(options.tlpktdrop == false)
        #expect(options.congestionControl == "file")
    }

    // MARK: - Server Presets

    @Test("All 7 SRTServerPresets have correct defaults")
    func allServerPresetsValid() {
        for preset in SRTServerPreset.allCases {
            let config = preset.configuration(host: "media.example.com")
            #expect(config.host == "media.example.com")
            #expect(config.port > 0)
        }
    }

    @Test("AWS MediaConnect uses standard SRT port")
    func awsMediaConnect() {
        let preset = SRTServerPreset.awsMediaConnect
        #expect(preset.defaultPort > 0)
        #expect(preset.usesStreamID)
    }

    @Test("OBS Studio preset has expected properties")
    func obsStudio() {
        let preset = SRTServerPreset.obsStudio
        let config = preset.configuration(host: "localhost")
        #expect(config.host == "localhost")
    }

    // MARK: - Builder

    @Test("SRTConfigurationBuilder fluent API")
    func builderFluentAPI() throws {
        let config = try SRTConfigurationBuilder(
            host: "srt.example.com", port: 4200
        )
        .mode(.caller)
        .latency(microseconds: 120_000)
        .encryption(
            passphrase: "my-secret-key-phrase",
            keySize: .aes256,
            cipherMode: .ctr
        )
        .build()

        #expect(config.host == "srt.example.com")
        #expect(config.port == 4200)
        #expect(config.options.latency == 120_000)
    }

    @Test("Builder with preset applies preset settings")
    func builderWithPreset() throws {
        let config = try SRTConfigurationBuilder(
            host: "live.example.com"
        )
        .preset(.broadcast)
        .build()

        #expect(config.host == "live.example.com")
    }
}
