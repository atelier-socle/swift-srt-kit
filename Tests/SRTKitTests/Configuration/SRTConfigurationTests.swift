// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import SRTKit

@Suite("SRTConfiguration Tests")
struct SRTConfigurationTests {
    // MARK: - Basic creation

    @Test("Default host is 0.0.0.0")
    func defaultHost() {
        let config = SRTConfiguration()
        #expect(config.host == "0.0.0.0")
    }

    @Test("Default port is 4200")
    func defaultPort() {
        let config = SRTConfiguration()
        #expect(config.port == 4200)
    }

    @Test("Default mode is .caller")
    func defaultMode() {
        let config = SRTConfiguration()
        #expect(config.mode == .caller)
    }

    @Test("Default options are SRTSocketOptions.default")
    func defaultOptions() {
        let config = SRTConfiguration()
        #expect(config.options == .default)
    }

    @Test("Default accessControl is nil")
    func defaultAccessControl() {
        let config = SRTConfiguration()
        #expect(config.accessControl == nil)
    }

    // MARK: - ConnectionMode

    @Test("ConnectionMode CaseIterable lists all 3")
    func connectionModeCaseIterable() {
        let cases = SRTConfiguration.ConnectionMode.allCases
        #expect(cases.count == 3)
        #expect(cases.contains(.caller))
        #expect(cases.contains(.listener))
        #expect(cases.contains(.rendezvous))
    }

    // MARK: - Validation

    @Test("Valid config does not throw")
    func validConfigNoThrow() throws {
        let config = SRTConfiguration(
            host: "192.168.1.1", port: 4200)
        try config.validate()
    }

    @Test("Port 0 throws portOutOfRange")
    func portZeroThrows() {
        let config = SRTConfiguration(host: "localhost", port: 0)
        #expect(throws: SRTConfigurationError.self) {
            try config.validate()
        }
    }

    @Test("Port 65536 throws portOutOfRange")
    func port65536Throws() {
        let config = SRTConfiguration(host: "localhost", port: 65536)
        #expect(throws: SRTConfigurationError.self) {
            try config.validate()
        }
    }

    @Test("Empty host with .caller throws callerRequiresHost")
    func emptyHostCallerThrows() throws {
        let config = SRTConfiguration(
            host: "", port: 4200, mode: .caller)
        do {
            try config.validate()
            Issue.record("Expected throw")
        } catch let error as SRTConfigurationError {
            if case .callerRequiresHost = error {
            } else {
                Issue.record("Expected callerRequiresHost, got \(error)")
            }
        }
    }

    // MARK: - Conversion

    @Test("callerConfiguration maps all fields")
    func callerConfigurationMapping() {
        var options = SRTSocketOptions()
        options.passphrase = "testpassphrase"
        options.keySize = .aes256
        options.cipherMode = .gcm
        options.latency = 200_000
        options.congestionControl = "file"
        options.connectTimeout = 5_000_000

        let ac = SRTAccessControl(resource: "live/stream1", mode: .publish)
        let config = SRTConfiguration(
            host: "10.0.0.1", port: 9000, options: options,
            accessControl: ac)
        let callerConfig = config.callerConfiguration()

        #expect(callerConfig.host == "10.0.0.1")
        #expect(callerConfig.port == 9000)
        #expect(callerConfig.passphrase == "testpassphrase")
        #expect(callerConfig.keySize == .aes256)
        #expect(callerConfig.cipherMode == .gcm)
        #expect(callerConfig.latency == 200_000)
        #expect(callerConfig.congestionControl == "file")
        #expect(callerConfig.connectTimeout == 5_000_000)
        #expect(callerConfig.streamID != nil)
    }

    @Test("listenerConfiguration maps all fields")
    func listenerConfigurationMapping() {
        var options = SRTSocketOptions()
        options.passphrase = "testpassphrase"
        options.keySize = .aes256
        options.cipherMode = .gcm
        options.latency = 200_000

        let config = SRTConfiguration(
            host: "0.0.0.0", port: 8080, mode: .listener,
            options: options)
        let listenerConfig = config.listenerConfiguration()

        #expect(listenerConfig.host == "0.0.0.0")
        #expect(listenerConfig.port == 8080)
        #expect(listenerConfig.passphrase == "testpassphrase")
        #expect(listenerConfig.keySize == .aes256)
        #expect(listenerConfig.cipherMode == .gcm)
        #expect(listenerConfig.latency == 200_000)
    }
}
