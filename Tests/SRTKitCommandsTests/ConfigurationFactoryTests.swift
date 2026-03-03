// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit
@testable import SRTKitCommands

@Suite("ConfigurationFactory Tests")
struct ConfigurationFactoryTests {

    // MARK: - Caller Configuration

    @Test("Caller config with all options")
    func callerConfigAllOptions() throws {
        let config = try ConfigurationFactory.callerConfiguration(
            host: "10.0.0.1", port: 9000,
            options: .init(
                streamID: "live/stream1",
                passphrase: "secret123",
                preset: "lowLatency",
                latency: 50)
        )
        #expect(config.host == "10.0.0.1")
        #expect(config.port == 9000)
        #expect(config.streamID == "live/stream1")
        #expect(config.passphrase == "secret123")
        #expect(config.latency == 50_000)  // ms -> us
    }

    @Test("Caller config with defaults")
    func callerConfigDefaults() throws {
        let config = try ConfigurationFactory.callerConfiguration(
            host: "127.0.0.1", port: 4200
        )
        #expect(config.host == "127.0.0.1")
        #expect(config.port == 4200)
        #expect(config.latency == 120_000)
        #expect(config.passphrase == nil)
        #expect(config.streamID == nil)
    }

    @Test("Invalid preset throws CLIError.invalidPreset")
    func invalidPresetThrows() {
        do {
            _ = try ConfigurationFactory.callerConfiguration(
                host: "localhost", port: 4200,
                options: .init(preset: "nonexistent")
            )
            Issue.record("Expected throw")
        } catch let error as CLIError {
            if case .invalidPreset(let name) = error {
                #expect(name == "nonexistent")
            } else {
                Issue.record("Expected invalidPreset error")
            }
        } catch {
            Issue.record("Expected CLIError")
        }
    }

    @Test("Passphrase sets encryption")
    func passphraseEnablesEncryption() throws {
        let config = try ConfigurationFactory.callerConfiguration(
            host: "localhost", port: 4200,
            options: .init(passphrase: "my-secret-passphrase")
        )
        #expect(config.passphrase == "my-secret-passphrase")
    }

    @Test("Latency ms to us conversion")
    func latencyConversion() throws {
        let config = try ConfigurationFactory.callerConfiguration(
            host: "localhost", port: 4200,
            options: .init(latency: 250)
        )
        #expect(config.latency == 250_000)
    }

    @Test("Preset overrides default latency")
    func presetOverridesLatency() throws {
        let config = try ConfigurationFactory.callerConfiguration(
            host: "localhost", port: 4200,
            options: .init(preset: "lowLatency")
        )
        // lowLatency preset uses 20ms = 20_000us
        #expect(config.latency == 20_000)
    }

    @Test("Latency override takes precedence over preset")
    func latencyOverrideBeatsPreset() throws {
        let config = try ConfigurationFactory.callerConfiguration(
            host: "localhost", port: 4200,
            options: .init(preset: "lowLatency", latency: 500)
        )
        #expect(config.latency == 500_000)
    }

    // MARK: - Listener Configuration

    @Test("Listener config with all options")
    func listenerConfigAllOptions() {
        let config = ConfigurationFactory.listenerConfiguration(
            bind: "10.0.0.1", port: 8080,
            passphrase: "listener-secret", latency: 200
        )
        #expect(config.host == "10.0.0.1")
        #expect(config.port == 8080)
        #expect(config.passphrase == "listener-secret")
        #expect(config.latency == 200_000)
    }

    @Test("Listener config with defaults")
    func listenerConfigDefaults() {
        let config = ConfigurationFactory.listenerConfiguration(
            bind: "0.0.0.0", port: 4200,
            passphrase: nil, latency: nil
        )
        #expect(config.host == "0.0.0.0")
        #expect(config.port == 4200)
        #expect(config.latency == 120_000)
        #expect(config.passphrase == nil)
    }
}
