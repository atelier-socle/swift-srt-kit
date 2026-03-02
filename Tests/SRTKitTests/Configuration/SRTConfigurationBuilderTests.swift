// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTConfigurationBuilder Tests")
struct SRTConfigurationBuilderTests {
    // MARK: - Fluent API

    @Test("Builder with host/port builds valid config")
    func basicBuild() throws {
        let config = try SRTConfigurationBuilder(host: "10.0.0.1", port: 9000)
            .build()
        #expect(config.host == "10.0.0.1")
        #expect(config.port == 9000)
    }

    @Test(".preset(.lowLatency) sets correct latency")
    func presetLowLatency() throws {
        let config = try SRTConfigurationBuilder(host: "10.0.0.1")
            .preset(.lowLatency)
            .build()
        #expect(config.options.latency == 20_000)
    }

    @Test(".serverPreset(.awsMediaConnect) sets correct options")
    func serverPresetAWS() throws {
        let config = try SRTConfigurationBuilder(host: "ingest.aws.com")
            .serverPreset(.awsMediaConnect, resource: "stream1")
            .build()
        #expect(config.options.latency == 1_000_000)
        #expect(config.accessControl != nil)
    }

    @Test(".encryption sets passphrase and keySize")
    func encryptionSetsFields() throws {
        let config = try SRTConfigurationBuilder(host: "10.0.0.1")
            .encryption(
                passphrase: "mysecretpassphrase", keySize: .aes256,
                cipherMode: .gcm
            )
            .build()
        #expect(config.options.passphrase == "mysecretpassphrase")
        #expect(config.options.keySize == .aes256)
        #expect(config.options.cipherMode == .gcm)
    }

    @Test(".latency sets latency")
    func latencySetsField() throws {
        let config = try SRTConfigurationBuilder(host: "10.0.0.1")
            .latency(microseconds: 50_000)
            .build()
        #expect(config.options.latency == 50_000)
    }

    @Test(".fec sets FEC configuration")
    func fecSetsField() throws {
        let fecConfig = try FECConfiguration(columns: 5, rows: 2)
        let config = try SRTConfigurationBuilder(host: "10.0.0.1")
            .fec(fecConfig)
            .build()
        #expect(config.options.fecConfiguration != nil)
        #expect(config.options.fecConfiguration?.columns == 5)
    }

    @Test(".maxBandwidth sets maxBandwidth")
    func maxBandwidthSetsField() throws {
        let config = try SRTConfigurationBuilder(host: "10.0.0.1")
            .maxBandwidth(100_000_000)
            .build()
        #expect(config.options.maxBandwidth == 100_000_000)
    }

    @Test(".congestionControl sets CC")
    func congestionControlSetsField() throws {
        let config = try SRTConfigurationBuilder(host: "10.0.0.1")
            .congestionControl("file")
            .build()
        #expect(config.options.congestionControl == "file")
    }

    @Test(".mode sets connection mode")
    func modeSetsField() throws {
        let config = try SRTConfigurationBuilder(host: "0.0.0.0")
            .mode(.listener)
            .build()
        #expect(config.mode == .listener)
    }

    @Test(".streamID sets access control")
    func streamIDSetsField() throws {
        let ac = SRTAccessControl(resource: "live/stream1", mode: .publish)
        let config = try SRTConfigurationBuilder(host: "10.0.0.1")
            .streamID(ac)
            .build()
        #expect(config.accessControl?.resource == "live/stream1")
    }

    // MARK: - Chaining

    @Test(".preset then .latency overrides preset's latency")
    func presetThenLatencyOverrides() throws {
        let config = try SRTConfigurationBuilder(host: "10.0.0.1")
            .preset(.lowLatency)
            .latency(microseconds: 50_000)
            .build()
        #expect(config.options.latency == 50_000)
    }

    @Test("Multiple chained methods apply correctly")
    func multipleChainingWorks() throws {
        let config = try SRTConfigurationBuilder(host: "10.0.0.1", port: 9000)
            .mode(.caller)
            .preset(.reliable)
            .encryption(passphrase: "my-long-passphrase")
            .maxBandwidth(50_000_000)
            .build()
        #expect(config.options.latency == 500_000)
        #expect(config.options.passphrase == "my-long-passphrase")
        #expect(config.options.maxBandwidth == 50_000_000)
    }

    // MARK: - Validation

    @Test("build() with invalid options throws")
    func buildWithInvalidThrows() {
        let builder = SRTConfigurationBuilder(host: "10.0.0.1")
            .encryption(passphrase: "short")
        #expect(throws: SRTConfigurationError.self) {
            try builder.build()
        }
    }

    @Test("buildUnchecked() with invalid options returns config")
    func buildUncheckedWithInvalid() {
        let config = SRTConfigurationBuilder(host: "10.0.0.1")
            .encryption(passphrase: "short")
            .buildUnchecked()
        #expect(config.options.passphrase == "short")
    }

    // MARK: - Preset + server preset combination

    @Test(".preset(.reliable) then .serverPreset overrides")
    func presetThenServerPresetOverrides() throws {
        let config = try SRTConfigurationBuilder(host: "ingest.aws.com")
            .preset(.reliable)
            .serverPreset(.awsMediaConnect, resource: "stream1")
            .build()
        // Server preset should override the preset's latency
        #expect(config.options.latency == 1_000_000)
    }
}
