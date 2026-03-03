// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Testing

@testable import SRTKitCommands

// MARK: - TestCommand Parsing Coverage

@Suite("TestCommand Parsing Coverage")
struct TestCommandParsingCoverageTests {

    // MARK: - Configuration

    @Test("TestCommand command name is 'test'")
    func commandName() {
        #expect(TestCommand.configuration.commandName == "test")
    }

    @Test("TestCommand abstract is set")
    func abstract() {
        #expect(
            TestCommand.configuration.abstract
                == "Run a loopback performance test")
    }

    // MARK: - Defaults

    @Test("TestCommand default duration is 5")
    func defaultDuration() throws {
        let cmd = try TestCommand.parse([])
        #expect(cmd.duration == 5)
    }

    @Test("TestCommand default bitrate is 5000")
    func defaultBitrate() throws {
        let cmd = try TestCommand.parse([])
        #expect(cmd.bitrate == 5000)
    }

    @Test("TestCommand default port is 9999")
    func defaultPort() throws {
        let cmd = try TestCommand.parse([])
        #expect(cmd.port == 9999)
    }

    @Test("TestCommand default latency is 120")
    func defaultLatency() throws {
        let cmd = try TestCommand.parse([])
        #expect(cmd.latency == 120)
    }

    // MARK: - Individual Options

    @Test("TestCommand --duration sets duration")
    func parseDuration() throws {
        let cmd = try TestCommand.parse(["--duration", "30"])
        #expect(cmd.duration == 30)
    }

    @Test("TestCommand --bitrate sets bitrate")
    func parseBitrate() throws {
        let cmd = try TestCommand.parse(["--bitrate", "20000"])
        #expect(cmd.bitrate == 20000)
    }

    @Test("TestCommand --port sets port")
    func parsePort() throws {
        let cmd = try TestCommand.parse(["--port", "7777"])
        #expect(cmd.port == 7777)
    }

    @Test("TestCommand --latency sets latency")
    func parseLatency() throws {
        let cmd = try TestCommand.parse(["--latency", "250"])
        #expect(cmd.latency == 250)
    }

    // MARK: - Combined Options

    @Test("TestCommand parses all options together")
    func allOptions() throws {
        let cmd = try TestCommand.parse([
            "--duration", "60",
            "--bitrate", "50000",
            "--port", "8888",
            "--latency", "500"
        ])
        #expect(cmd.duration == 60)
        #expect(cmd.bitrate == 50000)
        #expect(cmd.port == 8888)
        #expect(cmd.latency == 500)
    }

    @Test("TestCommand parses options in any order")
    func optionsAnyOrder() throws {
        let cmd = try TestCommand.parse([
            "--latency", "80",
            "--port", "3000",
            "--duration", "15",
            "--bitrate", "1000"
        ])
        #expect(cmd.latency == 80)
        #expect(cmd.port == 3000)
        #expect(cmd.duration == 15)
        #expect(cmd.bitrate == 1000)
    }

    // MARK: - Edge Values

    @Test("TestCommand allows zero duration")
    func zeroDuration() throws {
        let cmd = try TestCommand.parse(["--duration", "0"])
        #expect(cmd.duration == 0)
    }

    @Test("TestCommand allows large bitrate")
    func largeBitrate() throws {
        let cmd = try TestCommand.parse(["--bitrate", "1000000"])
        #expect(cmd.bitrate == 1_000_000)
    }

    @Test("TestCommand allows port 1")
    func portOne() throws {
        let cmd = try TestCommand.parse(["--port", "1"])
        #expect(cmd.port == 1)
    }

    @Test("TestCommand allows port 65535")
    func portMax() throws {
        let cmd = try TestCommand.parse(["--port", "65535"])
        #expect(cmd.port == 65535)
    }

    // MARK: - Parse Errors

    @Test("TestCommand rejects non-integer duration")
    func rejectNonIntDuration() {
        #expect(throws: (any Error).self) {
            try TestCommand.parse(["--duration", "abc"])
        }
    }

    @Test("TestCommand rejects non-integer bitrate")
    func rejectNonIntBitrate() {
        #expect(throws: (any Error).self) {
            try TestCommand.parse(["--bitrate", "fast"])
        }
    }

    @Test("TestCommand rejects non-integer port")
    func rejectNonIntPort() {
        #expect(throws: (any Error).self) {
            try TestCommand.parse(["--port", "abc"])
        }
    }

    @Test("TestCommand rejects non-integer latency")
    func rejectNonIntLatency() {
        #expect(throws: (any Error).self) {
            try TestCommand.parse(["--latency", "low"])
        }
    }

    @Test("TestCommand rejects unknown option")
    func rejectUnknownOption() {
        #expect(throws: (any Error).self) {
            try TestCommand.parse(["--unknown", "value"])
        }
    }

    @Test("TestCommand rejects floating-point duration")
    func rejectFloatDuration() {
        #expect(throws: (any Error).self) {
            try TestCommand.parse(["--duration", "3.5"])
        }
    }
}

// MARK: - ProbeCommand Parsing Coverage

@Suite("ProbeCommand Parsing Coverage")
struct ProbeCommandParsingCoverageTests {

    // MARK: - Configuration

    @Test("ProbeCommand command name is 'probe'")
    func commandName() {
        #expect(ProbeCommand.configuration.commandName == "probe")
    }

    @Test("ProbeCommand abstract is set")
    func abstract() {
        #expect(
            ProbeCommand.configuration.abstract
                == "Probe available bandwidth and get recommendations")
    }

    // MARK: - Defaults

    @Test("ProbeCommand default host is 127.0.0.1")
    func defaultHost() throws {
        let cmd = try ProbeCommand.parse([])
        #expect(cmd.host == "127.0.0.1")
    }

    @Test("ProbeCommand default port is 4200")
    func defaultPort() throws {
        let cmd = try ProbeCommand.parse([])
        #expect(cmd.port == 4200)
    }

    @Test("ProbeCommand default mode is standard")
    func defaultMode() throws {
        let cmd = try ProbeCommand.parse([])
        #expect(cmd.mode == "standard")
    }

    @Test("ProbeCommand default target is balanced")
    func defaultTarget() throws {
        let cmd = try ProbeCommand.parse([])
        #expect(cmd.target == "balanced")
    }

    // MARK: - Individual Options

    @Test("ProbeCommand --host sets host")
    func parseHost() throws {
        let cmd = try ProbeCommand.parse(["--host", "192.168.1.100"])
        #expect(cmd.host == "192.168.1.100")
    }

    @Test("ProbeCommand --port sets port")
    func parsePort() throws {
        let cmd = try ProbeCommand.parse(["--port", "5555"])
        #expect(cmd.port == 5555)
    }

    @Test("ProbeCommand --mode sets mode to quick")
    func parseModeQuick() throws {
        let cmd = try ProbeCommand.parse(["--mode", "quick"])
        #expect(cmd.mode == "quick")
    }

    @Test("ProbeCommand --mode sets mode to thorough")
    func parseModeThorough() throws {
        let cmd = try ProbeCommand.parse(["--mode", "thorough"])
        #expect(cmd.mode == "thorough")
    }

    @Test("ProbeCommand --target sets target to quality")
    func parseTargetQuality() throws {
        let cmd = try ProbeCommand.parse(["--target", "quality"])
        #expect(cmd.target == "quality")
    }

    @Test("ProbeCommand --target sets target to lowLatency")
    func parseTargetLowLatency() throws {
        let cmd = try ProbeCommand.parse(["--target", "lowLatency"])
        #expect(cmd.target == "lowLatency")
    }

    // MARK: - Combined Options

    @Test("ProbeCommand parses all options together")
    func allOptions() throws {
        let cmd = try ProbeCommand.parse([
            "--host", "10.0.0.5",
            "--port", "9090",
            "--mode", "thorough",
            "--target", "quality"
        ])
        #expect(cmd.host == "10.0.0.5")
        #expect(cmd.port == 9090)
        #expect(cmd.mode == "thorough")
        #expect(cmd.target == "quality")
    }

    @Test("ProbeCommand parses host and mode only")
    func hostAndMode() throws {
        let cmd = try ProbeCommand.parse([
            "--host", "example.com",
            "--mode", "quick"
        ])
        #expect(cmd.host == "example.com")
        #expect(cmd.mode == "quick")
        #expect(cmd.port == 4200)
        #expect(cmd.target == "balanced")
    }

    // MARK: - Parse Errors

    @Test("ProbeCommand rejects non-integer port")
    func rejectNonIntPort() {
        #expect(throws: (any Error).self) {
            try ProbeCommand.parse(["--port", "abc"])
        }
    }

    @Test("ProbeCommand rejects unknown option")
    func rejectUnknownOption() {
        #expect(throws: (any Error).self) {
            try ProbeCommand.parse(["--verbose"])
        }
    }

    @Test("ProbeCommand rejects missing option value for --host")
    func rejectMissingHostValue() {
        #expect(throws: (any Error).self) {
            try ProbeCommand.parse(["--host"])
        }
    }

    @Test("ProbeCommand rejects missing option value for --port")
    func rejectMissingPortValue() {
        #expect(throws: (any Error).self) {
            try ProbeCommand.parse(["--port"])
        }
    }
}

// MARK: - SendCommand Parsing Coverage

@Suite("SendCommand Parsing Coverage")
struct SendCommandParsingCoverageTests {

    // MARK: - Configuration

    @Test("SendCommand command name is 'send'")
    func commandName() {
        #expect(SendCommand.configuration.commandName == "send")
    }

    @Test("SendCommand abstract is set")
    func abstract() {
        #expect(
            SendCommand.configuration.abstract
                == "Send data to an SRT listener")
    }

    // MARK: - Defaults

    @Test("SendCommand default host is 127.0.0.1")
    func defaultHost() throws {
        let cmd = try SendCommand.parse([])
        #expect(cmd.host == "127.0.0.1")
    }

    @Test("SendCommand default port is 4200")
    func defaultPort() throws {
        let cmd = try SendCommand.parse([])
        #expect(cmd.port == 4200)
    }

    @Test("SendCommand default file is nil")
    func defaultFile() throws {
        let cmd = try SendCommand.parse([])
        #expect(cmd.file == nil)
    }

    @Test("SendCommand default streamID is nil")
    func defaultStreamID() throws {
        let cmd = try SendCommand.parse([])
        #expect(cmd.streamID == nil)
    }

    @Test("SendCommand default passphrase is nil")
    func defaultPassphrase() throws {
        let cmd = try SendCommand.parse([])
        #expect(cmd.passphrase == nil)
    }

    @Test("SendCommand default preset is nil")
    func defaultPreset() throws {
        let cmd = try SendCommand.parse([])
        #expect(cmd.preset == nil)
    }

    @Test("SendCommand default latency is nil")
    func defaultLatency() throws {
        let cmd = try SendCommand.parse([])
        #expect(cmd.latency == nil)
    }

    // MARK: - Individual Options

    @Test("SendCommand --host sets host")
    func parseHost() throws {
        let cmd = try SendCommand.parse(["--host", "10.0.0.99"])
        #expect(cmd.host == "10.0.0.99")
    }

    @Test("SendCommand --port sets port")
    func parsePort() throws {
        let cmd = try SendCommand.parse(["--port", "6000"])
        #expect(cmd.port == 6000)
    }

    @Test("SendCommand --file sets file path")
    func parseFile() throws {
        let cmd = try SendCommand.parse(["--file", "/tmp/video.ts"])
        #expect(cmd.file == "/tmp/video.ts")
    }

    @Test("SendCommand --stream-id sets streamID")
    func parseStreamID() throws {
        let cmd = try SendCommand.parse(["--stream-id", "#!::r=live,m=publish"])
        #expect(cmd.streamID == "#!::r=live,m=publish")
    }

    @Test("SendCommand --passphrase sets passphrase")
    func parsePassphrase() throws {
        let cmd = try SendCommand.parse(["--passphrase", "my-long-passphrase-here"])
        #expect(cmd.passphrase == "my-long-passphrase-here")
    }

    @Test("SendCommand --preset sets preset")
    func parsePreset() throws {
        let cmd = try SendCommand.parse(["--preset", "reliable"])
        #expect(cmd.preset == "reliable")
    }

    @Test("SendCommand --latency sets latency")
    func parseLatency() throws {
        let cmd = try SendCommand.parse(["--latency", "300"])
        #expect(cmd.latency == 300)
    }

    // MARK: - Combined Options

    @Test("SendCommand parses all options together")
    func allOptions() throws {
        let cmd = try SendCommand.parse([
            "--host", "192.168.0.1",
            "--port", "7000",
            "--file", "input.ts",
            "--stream-id", "test-stream",
            "--passphrase", "secret",
            "--preset", "broadcast",
            "--latency", "200"
        ])
        #expect(cmd.host == "192.168.0.1")
        #expect(cmd.port == 7000)
        #expect(cmd.file == "input.ts")
        #expect(cmd.streamID == "test-stream")
        #expect(cmd.passphrase == "secret")
        #expect(cmd.preset == "broadcast")
        #expect(cmd.latency == 200)
    }

    @Test("SendCommand parses host, port, and passphrase")
    func hostPortPassphrase() throws {
        let cmd = try SendCommand.parse([
            "--host", "srt.example.com",
            "--port", "4201",
            "--passphrase", "encryption-key"
        ])
        #expect(cmd.host == "srt.example.com")
        #expect(cmd.port == 4201)
        #expect(cmd.passphrase == "encryption-key")
        #expect(cmd.file == nil)
        #expect(cmd.preset == nil)
    }

    // MARK: - Parse Errors

    @Test("SendCommand rejects non-integer port")
    func rejectNonIntPort() {
        #expect(throws: (any Error).self) {
            try SendCommand.parse(["--port", "not-a-number"])
        }
    }

    @Test("SendCommand rejects non-integer latency")
    func rejectNonIntLatency() {
        #expect(throws: (any Error).self) {
            try SendCommand.parse(["--latency", "high"])
        }
    }

    @Test("SendCommand rejects unknown flag")
    func rejectUnknownFlag() {
        #expect(throws: (any Error).self) {
            try SendCommand.parse(["--verbose"])
        }
    }

    @Test("SendCommand rejects positional arguments")
    func rejectPositionalArgs() {
        #expect(throws: (any Error).self) {
            try SendCommand.parse(["somearg"])
        }
    }
}
